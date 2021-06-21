# COVID Policy Modelling Model Connector Template

This repository is a template for model connectors used to add new models to the COVID Policy Modelling web-ui.

## Content

* [Assumptions](#assumptions)
* [Process](#process)
* [Requirements for Docker images](#requirements-for-docker-images)
* [Input](#input)
* [Output](#output)
* [Alternative ntegrations](#alternative-integrations)
* [Examples](#examples)

## Assumptions

This repository and these instructions assume the following:

* The *connector code* will be in a Github repository (public or private)
  * *connector code* acts as an interface between the inputs obtained from the web interface (as a JSON file) and the outputs generated by your model also expressed as a JSON file. Both the inputs and outpus have to conform to input or output JSON schema respectively
* The *connector* can be developed in a repository separate to any others used by your model
* The Docker images will be published automatically using [Github Actions](https://docs.github.com/en/actions)
* The Docker image will be published to Github Packages (not Github Container Registry)

These are not requirements for integrating a model, but you should read the *Alternative integrations* section later in the document for more information.

## Process


1. Fork this repository

1. To start, make sure that your code can be run at the command line

1. Create a [Dockerfile](https://docs.docker.com/engine/reference/builder/), loading all the necessary dependencies to run your model/code, and ensure that your model/code can run in this docker instance

1. Obtain a copy of the latest version of the input and output versionof the JSON schema: 
    ```bash
    $ curl https://raw.githubusercontent.com/covid-policy-modelling/model-runner/main/packages/api/schema/input.json -o input-schema.json
    $ curl https://raw.githubusercontent.com/covid-policy-modelling/model-runner/main/packages/api/schema/output.json -o output-schema.json
    ```
    
1. Develop your connector (iteratively):
   1. Create connector code (in a language of your choice) to transform the input/output from the COVID Policy Modelling schemas to/from the input/output your model uses, as described in more detail below
   1. Edit `Dockerfile` to create an image containing both your model and connector code, with any dependencies, as described in more detail below
   1. Test your connector code by running `docker-compose run test`
      * You may need to edit `test-job.json` if your model does not support the parameters specified in the file.
   1. Validate the output of your connector by running `docker-compose run validate`
   1. Push your changes to Github, and ensure the Docker image is built and published successfully
   
1. Edit `meta.yml` to describe your model/connector

1. If you're developing in a private repository, give the @covid-policy-modelling-bot Read access to your repository

1. Raise a PR against the `web-ui` repository, copying the content of your `meta.yml` into the `models.yml` file

## Requirements for Docker images

- The command must return:
  - a non-zero status code if the simulation fails, and 
  - zero otherwise (for sucess)
- The container must not require any arguments in order to carry out the simulation
  - Specify [`ENTRYPOINT`](https://docs.docker.com/engine/reference/builder/#entrypoint) or [`CMD`](https://docs.docker.com/engine/reference/builder/#cmd) appropriately in such a way that the container can be executed with no special arguments or other knowledge.
  - Do not specify any additional arguments in `docker-compose.yml`
- If your model requires additional data beyond that given in the input schema, either:
  - Add it your container at build-time, e.g. with [`ADD`](https://docs.docker.com/engine/reference/builder/#add)/[`COPY`](https://docs.docker.com/engine/reference/builder/#copy)/[`RUN`](https://docs.docker.com/engine/reference/builder/#run)
  - Download it in your connector code
- At run-time, 
  - Copy/store any input data into `/data/input/inputFile.json` 
    - `/data/input/` will be volume mounted into the container, and will be available for download in the UI after completion
  - Copy/store any output data in `/data/output/data.json` 
    - `/data/output` will be volume mounted into the container, and will be available for download in the UI after completion
- Any messages that are printed to STDOUT will not be displayed to end-users, but can be useful for debugging in the backend
- Any additional logging should be copied/stored in `/data/log` (this will be volume mounted into the container, but will not be available for download by default)

### Input

A file with all of the required input information will be mounted into the container as: 

* `/data/input/inputFile.json`.

This file will contain JSON that satisfies the generalized [`ModelInput` schema](https://github.com/covid-policy-modelling/model-runner/blob/main/packages/api/schema/input.json) (you can also use the [less-formal but more readable source](https://github.com/covid-policy-modelling/model-runner/blob/main/packages/api/src/model-input.ts)).

A schematic example of what an `inputFile.json` will look like is shown belo (note JSON does not support comments so they are included here only for guidance). The `region` and all values in the `parameters` section are required but  specifying a `subregion` is optional. The ordering of values within a section may also vary:

```html
   <!-- A generalized description of the input to an epidemiological model. -->
{
   <!-- ISO 3166 country code for the region results correspond to, e.g. "GB",
        see https://www.iso.org/iso-3166-country-codes.html. -->
   "region": "GB",
   <!-- Optional specification of a subregion. -->
   "subregion":"GB-ENG",
   "parameters":{
        <!-- An ISO-8601 string encoding the date of the most recent case data in 
             the region. -->
        "calibrationDate": "2021-06-17",
        <!-- The total number of confirmed cases in the region before the 
             calibration date. -->
        "calibrationCaseCount": 1400,
        <!-- The total number of deaths in the region before the calibration date. -->
        "calibrationDeathCount": 200,
        <!-- A list of time periods, each with a different set of interventions. -->
        "interventionPeriods": [      
        {
            <!-- An ISO-8601 string encoding the date that these interventions 
                 begin. -->
            "startDate": "2020-03-15",
            <!-- The estimated reduction in population contact resulting from
                 all of the above interventions. Some models require this       
                 generalized parameter instead of the individual interventions.
             -->
            "reductionPopulationContact": 15,
             <!-- One or more of:
                  "caseIsolation"     - The level to which individuals with symptoms 
                                        self-isolate.
                   "schoolClosure"    - The level of school closure in the region.
                   "socialDistancing" - The level of social distancing in the region.
                   "voluntaryHomeQuarantine" - The level to which entire households 
                                               self-isolate when one member of the
                                               household has symptoms.
                    which can have a value of: "mild", "moderate", "aggressive"
             -->
            "socialDistancing": "moderate"
          },
          {
            <!-- More interventions -->
          }
        ],
        <!-- The assumed reproduction number for the virus. If this is null, then
             each model will use its own default value. -->
        "r0": null
  }
 
}
```

Of course your model/code may choose to ignore some or most of all of these. However, if you are asked to model a specific `region` it will not look so good if you return the results for a completely different `region`.

Your connector code should transform this input into whichever parameters or input files your model accepts (if your model already accepts input in this format, the connector can simply pass it on).

Not all input parameters may be appropriate for your model, but you should make use of those you can, and document `meta.yml` accordingly.

### Output

Your container is expected to create a fileafter the simulation:

*  `/data/output/data.json`

This file should contain JSON that satisfies the generalized [`ModelOutput` schema](https://github.com/covid-policy-modelling/model-runner/blob/main/packages/api/schema/output.json) (you can also use the [less-formal but more readable source](https://github.com/covid-policy-modelling/model-runner/blob/main/packages/api/src/model-output.ts)).

An illustrative example `data.json` instance document is given below to show the expected sample output (note that JSON does NOT support comments and are included blow purely for guidance) as a JSON schema may not be easy to read. The order of items in the `time`, `metadata` and `aggregate` sections is not important but, other than for the `R` number in the `aggregate` section, they must all be there.

```html
{
    <!-- A generalized description of the outputs of an epidemiological model. -->
    "time": {
        <!-- An ISO-8601, e.g. "2021-05-27, string encoding the date that each 
             timeseries begins. -->
        "t0": "2021-05-21",
        <!-- Each timestamp value is a number of days after `t0` that correspond 
             to every series of metrics output for `t0` counts as 0. -->
        "timestamps": [1,2,3, ... , 100],
        <!-- The minimum and maximum timestamps for the series of reported metrics.
             Each value is a number of days after `t0`. -->
        "extent": [1,100]
    },
    "metadata": {
         <!-- ISO 3166 country code for the region results correspond to, e.g. "GB",
              see https://www.iso.org/iso-3166-country-codes.html. -->
        "region": "GB",
         <!-- Subregion being modeled within the region above. -->
        "subregion": "England",
        "parameters": {
            <!-- The total number of confirmed cases in the region before 
                 the calibration date. -->
            "calibrationCaseCount": 1400,
            <!-- An ISO-8601 string encoding the date of the most recent case 
                 data in the region. -->
            "calibrationDate": "2021-05-21",
            <!-- The assumed reproduction number for the virus. If this is null, 
                 then each model will use its own default value. -->
            "r0": null,
            <!-- The total number of deaths in the region before the calibration date. -->
            "calibrationDeathCount": 200,
            <!-- A list of time periods, each with a different set of interventions. -->
            "interventionPeriods": [
               <!-- Array of objects where the "startDate" and 
                "reductionPopulationContact" are required but the order in which
                elements are listed is not important. -->
                {
                 <!-- An ISO-8601 string encoding the date that these interventions 
                      begin. -->
                 "startDate": "2021-06-21",
                 <!-- One or more of:
                      "caseIsolation"    - The level to which individuals with symptoms 
                                           self-isolate.
                      "schoolClosure"    - The level of school closure in the region.
                      "socialDistancing" - The level of social distancing in the region.
                      "voluntaryHomeQuarantine" - The level to which entire households 
                                                  self-isolate when one member of the
                                                  household has symptoms.
                       which can have a value of: "mild", "moderate", "aggressive"
                  -->
                  "schoolClosure": "mild",
                  "caseIsolation": "aggressive",
                  "voluntaryHomeQuarantine": "moderate",
                  <!-- The estimated reduction in population contact resulting from
                       all of the above interventions. Some models require this       
                       generalized parameter instead of the individual interventions.
                   -->
                  "reductionPopulationContact": 34
                },
                { <!-- Another intervention and so on -->}
             ]
        }
    },
    <!-- Each output below is an array corresponding to the `extent` specified above.
         If a particular metric is not supported an array of zeros can be given. -->
    "aggregate": {
        "metrics": {
            <!-- Current number of critical cases on this day (assume represents 
                 ICU demand). -->
            "Critical": [],
            <!-- Current number of critical cases on this day who are well enough 
                 to leave the ICU but still need a hospital bed. -->
            "CritRecov": [],
            <!-- Total number of critical cases since the beginning of the epidemic. -->
            "cumCritical": [],
            <!-- Total number of patients recovered from critical cases since 
                 the beginning of the epidemic. -->
            "cumCritRecov": [],
            <!-- Total number of influenza-like illnesses since the beginning of 
                 the epidemic. -->
            "cumILI": [],
            <!-- Total number of mild cases since the beginning of the epidemic. -->
            "cumMild": [],
            <!-- Current number of Severe Acute Respiratory Illness cases on 
                 this day (assume represents hospital demand). -->
            "SARI": [],
            <!-- Total number of severe acute respiratory illnesses since the beginning 
                 of the epidemic. -->
            "cumSARI": [],
            <!-- Current number of influenza-like illness cases on this day 
                (assume represents GP demand). -->
            "ILI": [],
            <-- Number of deaths occurring on this day. -->
            "incDeath": [],
            <!-- Current number of mild cases on this day. -->
            "Mild": [],
            <!-- R-number on this day. -->
            "R": []
        }
    }

}
```



Your connector code should transform the output of your model into this format (again, if your model already produces output in this format, the connector can simply pass it on)

Again, not all the output parameters may be appropriate for your model.
If the metric is optional (e.g. `R`) you can simply omit it.
At present, only some metrics are optional.
For others, you should output an array of the same length as `timestamps`, with all entries set to `0`.

## Alternative integrations

* You can develop your connector code in the same repository as your model
  * In that case, instead of forking simply download the files from this repository into appropriate locations in your repository
* You can publish Docker images to any registry (Github Container Registry, Docker Hub, Azure Container Registry etc.)
  * You will need to edit the workflow definitions in `.github/workflows` and the `imageURL` in `meta.yml`
  * If your image is private, contact us to discuss appropriate access credentials
* You can use an alternative CI system, or push images manually, or develop your code outside of Github
  * Remove the `.github/workflows` directory (although the files in there should help you identify what steps you need to follow to integrate with your desired approach)

## Examples

The following existing connectors can be used as examples.
Note that these have not necessarily used this template, and so may be laid out in a different format (i.e. as described in *Alternative integrations*).
These are written in several languages (Python, R, TypeScript).
Your connector can be in any language.

* https://github.com/covid-modeling/covasim-connector
* https://github.com/gjackland/WSS
* https://github.com/covid-policy-modelling/model-runner/tree/main/packages/mrc-ide-covidsim
* https://github.com/covid-policy-modelling/model-runner/tree/main/packages/neherlab-covid-19-scenarios

