# COVID Policy Modelling Model Connector Template

This repository is a template for model connectors used to add new models to the COVID Policy Modelling web-ui.

A model connector acts as the interface between the web interface and your model.
It needs to:

* Translate the inputs supplied by the web interface (provided to the connector as a JSON file) to the inputs used by your model.
* Executes your model.
* Translates the output from your model into the output expected by the web interface (again, as a JSON file).

Both the input and output have to conform to input or output JSON schema respectively.

## Content

* [Prerequisites](#prerequisites)
* [Assumptions](#assumptions)
* [Process](#process)
* [Requirements for Docker images](#requirements-for-docker-images)
* [Input](#input)
* [Output](#output)
* [Updating your model](#updating-your-model)
* [Alternative integrations](#alternative-integrations)
* [Examples](#examples)

## Prerequisites

To get this framework to work you will need to have the following tooling installed in your system:

* Either:
  * [Docker Desktop](https://www.docker.com/products/docker-desktop) (only for Windows/macOS) or
  * [Docker Engine](https://docs.docker.com/engine/install/) and [Docker Compose](https://docs.docker.com/engine/install/)

## Assumptions

This repository and these instructions assume the following:

* The *connector* will be in a Github repository (public or private).
* The *connector* will be developed in a repository separate to any others used by your model.
* The Docker images will be published automatically using [Github Actions](https://docs.github.com/en/actions).
* The Docker image will be published to Github Packages (not the Github Container Registry).

These are not requirements for integrating a model, but you should read the [*Alternative integrations*](#alternative-integrations) section later in the document for more information.

The document also assumes a basic knowledge of Docker, JSON & JSON Schema.
For more information on these:

* [Docker - Getting Started](https://docs.docker.com/get-started/) - Parts 1-3 & 9 are most relevant.
* [Dockerfile Reference](https://docs.docker.com/engine/reference/builder/).
* [Docker Compose](https://docs.docker.com/compose/).
* [Ten simple rules for writing Dockerfiles for reproducible data science](https://doi.org/10.1371/journal.pcbi.1008316).
* [JSON](https://developer.mozilla.org/en-US/docs/Glossary/JSON).
* [JSON Schema](http://json-schema.org/learn/getting-started-step-by-step).

## Process


1. Fork this repository.

1. Ensure that your code can be run using the command line, e.g. using `Rscript` rather than *RStudio*, etc.

1. Obtain a copy of the latest version of the output JSON schema:

    ```bash
    curl https://raw.githubusercontent.com/covid-policy-modelling/schemas/main/schema/output.json -o output-schema.json
    ```

1. Develop your connector (iteratively):
   1. Create connector code (in a language of your choice) to transform the input/output from the COVID Policy Modelling schemas to/from the input/output your model uses, as described in more detail below, and execute your model.
   1. Edit the [Dockerfile](./Dockerfile) to contain your model and connector code:
      * Set an appropriate base image (if you already package your model as a Docker image, you can use this as the base image and some of the later steps will not be needed).
      * Install any necessary dependencies to run your model.
      * Add your model code to the image (e.g. using [RUN git clone](https://docs.docker.com/engine/reference/builder/#run) or `RUN wget`, etc.)
      * Add the connector code (e.g. using [COPY](https://docs.docker.com/engine/reference/builder/#copy)).
      * Set the `CMD` to run your connector code.
      * Some further requirements are described in more detail below.
   1. Build your image by running `docker-compose build run-model`.
   1. Test your connector code by running `docker-compose run run-model`.
      * You may need to edit the sample input file [test-job.json](test-job.json) if your model does not support the parameters specified in the file.
   1. Validate the output of your connector by running `docker-compose run --rm validate`.
   1. Push your changes to Github, and ensure the Docker image is built and published successfully.

1. Tag your model connector (`git tag v<version>`, e.g. `git tag v0.0.1`) and push the tag to GitHub. Ensure the Docker image is built and published successfully.

1. Edit [meta.yml](meta.yaml) to describe your model/connector.

1. If you are developing in a private repository, make sure to give the appropriate machine user access to your repository for any deployment that will use your connector (e.g. for the staging server, give the @covid-policy-modelling-bot *Read* access to your repository).

1. Raise a PR against the `web-ui` repository, copying the content of your `meta.yml` into the `models.yml` file.

1. Maintainers can then follow the instructions for *Deploying updated code > model connectors* from `infrastructure/README.md` to release the model.

## Requirements for Docker images

* The CMD/connector must return:
  * a zero status if the simulation succeeds (e.g. with `exit`, `sys.exit()` or whatever is appropriate for your language)
  * a non-zero status if the simulation fails. A connector *may* use specific codes to indicate different types of errors, but this is not required. At present, the error codes understood by the model-runner are:
    * `10` - The connector does not support the requested region/subregion
  * If the model already returns an appropriate status, the connector can simply pass it on. Otherwise the connector code should check the model output/logs for appropriate messages.
* The container must not require any arguments in order to carry out the simulation:
  * Specify [`CMD`](https://docs.docker.com/engine/reference/builder/#cmd) (or [`ENTRYPOINT`](https://docs.docker.com/engine/reference/builder/#entrypoint)) appropriately in such a way that the container can be executed with no special arguments or other knowledge.
  * Do not specify any additional arguments in `docker-compose.yml`.
* If your model requires additional data beyond that given in the input schema, either:
  * Add it your repository and add it to the container at build-time, e.g. with [`COPY`](https://docs.docker.com/engine/reference/builder/#copy)/[`ADD`](https://docs.docker.com/engine/reference/builder/#add)
  * Download it to the container at build-time, e.g. with [`RUN wget`](https://docs.docker.com/engine/reference/builder/#run).
  * Download it in your connector code.
* At run-time,
  * Copy/store any additional input data into `/data/input/`
    * `/data/input/` will be volume mounted into the container, and will be available for download in the UI after completion (useful for audit/reproducibility purposes).
  * Copy/store any additional output data in `/data/output/`
    * `/data/output` will be volume mounted into the container, and will be available for download in the UI after completion (useful for users to explore the output of your model beyond that included in the web-ui).
* Any messages that are printed to STDOUT will not be displayed to end-users, but can be useful for debugging in the backend.
* Any additional logging should be copied/stored in `/data/log` (this will be volume mounted into the container, but will not be available for download by default).

### Input

A file with all of the required input information will be mounted into the container as *`/data/input/inputFile.json`*.

This file will contain JSON that satisfies the [`ModelInput` schema](https://github.com/covid-policy-modelling/schemas/blob/main/schema/input.json) (you may also wish to refer to the [less-formal but more readable source](https://github.com/covid-policy-modelling/schemas/blob/main/src/model-input.ts)).

An expanded example of an `inputFile.json` is shown below (note JSON does not support comments so they are included here only for guidance).

```javascript
   <!-- A generalized description of the input to an epidemiological model. -->
{
   <!-- ISO-3166 country code for the region results correspond to, e.g. "GB",
        see https://www.iso.org/iso-3166-country-codes.html. -->
   "region": "GB",
   <!-- Optional specification of a subregion. Usually an ISO-3166-2 subdivsion
        code, but may be a code from some other recognised source, e.g. ONS in
        the UK. -->
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
                  "caseIsolation" - The level to which individuals with symptoms
                                    self-isolate.
                  "schoolClosure" - The level of school closure in the region.
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

Your connector code should transform this input into whichever parameters or input files your model accepts (if your model already accepts input in this format, the connector can simply pass it on).

The `region` and all values in the `parameters` section will always be provided, but the `subregion` may be omitted.
The ordering of keys within an object may also vary.

Your connector may choose to ignore some of the parameters.
The connector must however at least take into account the specified `region` and `subregion` and either produce results for that geography, or return an error.
You should document `meta.yml` with the supported parameters.

### Output

After the simulation, your connector is expected to create the file *`/data/output/data.json`*.

This file should contain JSON that satisfies the [`ModelOutput` schema](https://github.com/covid-policy-modelling/schemas/blob/main/schema/output.json) (you may also wish to refer the [less-formal but more readable source](https://github.com/covid-policy-modelling/schemas/blob/main/src/model-output.ts)).

An expanded example `data.json` is shown below (note JSON does not support comments so they are included here only for guidance).

```javascript
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
    <!-- Information about your model -->
    "model": {
        <!-- A short display name to identify the model. Usually the same as in meta.yml -->
        "name": "Demo Model",
        <!-- A version number identifying the version of the model used in this run.
             This should be a number that is meaningful to you, e.g. the output from
             `./demo-model --version` -->
        "modelVersion": "0.0.0",
        <!-- A version number identifying the version of the connector used in this run.
             If you are using the sample Dockerfile/GitHub Actions definition, this can be obtained
             from the environment variable `CONNECTOR_VERSION`. -->
        "connectorVersion": "0.0.0"
    },
    <!-- A copy of the input data -->
    "metadata": {
        "region": "GB",
        "subregion": "England",
        "parameters": {
            "calibrationCaseCount": 1400,
            "calibrationDate": "2021-05-21",
            "r0": null,
            "calibrationDeathCount": 200,
            "interventionPeriods": [
                {
                 "startDate": "2021-06-21",
                  "schoolClosure": "mild",
                  "caseIsolation": "aggressive",
                  "voluntaryHomeQuarantine": "moderate",
                  "reductionPopulationContact": 34
                }
             ]
        }
    },
    <!-- Each output below is an array corresponding to the `extent` specified above.
         If a particular metric is not supported an array of zeros can be given.
         Other than for the R values all numbers given SHOULD be integers. -->
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

Your connector code should transform the output of your model into this format (again, if your model already produces output in this format, the connector can simply pass it on).

The order of keys in the `time`, `metadata` and `aggregate` objects is not important.
All keys (except `R`) in the `aggregate` object are required.
Not all these output parameters may be appropriate for your model.
For these, you should output an array of the same length as `timestamps`, with all entries set to `0`.
For `R`, if your model does not produce this, you can simply omit the key.

## Updating your model

Changes to models should be made by following a similar approach to initial creation.

1. Make and test changes to your model / connector code.
1. Edit `meta.yml` with any new parameters / regions etc. if necessary
  1. Raise a PR against the `web-ui` repository, to make the same change to the `models.yml` file.
1. Tag your model connector (`git tag v<version>`, e.g. `git tag v0.0.2`) and push the tag to GitHub. Ensure the Docker image is build and published successfully.
1. Notify the maintainers of any infrastructure that deploys a specific version of your model (e.g in `web-ui/.override-staging/models.yml`)
  1. Maintainers can then follow the instructions for *Deploying updated code > model connectors* from `infrastructure/README.md` to release the model.

## Alternative integrations

* You can develop your connector code in the same repository as your model.
  * In that case, instead of forking simply download the files from this repository into appropriate locations in your repository.
  * Instead of downloading your model into the container, you can instead use `COPY`.
* You can publish Docker images to any registry (Github Container Registry, Docker Hub, Azure Container Registry etc.).
  * You will need to edit the workflow definitions in `.github/workflows` and the `imageURL` in `meta.yml`.
  * If your image is private, contact us to discuss appropriate access credentials.
* You can use an alternative CI system, or push images manually, or develop your code outside of Github
  * Remove the `.github/workflows` directory (although the files in there should help you identify what steps you need to follow to integrate with your desired approach).

## Examples

The following existing connectors can be used as examples.
Note that these have not necessarily used this template, and so may be laid out in a different format (i.e. as described in *Alternative integrations*).
These are written in several languages (Python, R, TypeScript).
Your connector can be in any language.

* https://github.com/covid-policy-modelling/covasim-connector
* https://github.com/gjackland/WSS
* https://github.com/covid-policy-modelling/covid-sim-connector
* https://github.com/covid-policy-modelling/basel-connector

