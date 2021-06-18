# COVID Policy Modelling Model Connector Template

This repository is a template for model connectors used to add new models to the COVID Policy Modelling web-ui.

## Assumptions

This repository and these instructions assume the following.
These aren't requirements for integrating a model, but you should read the *Alternative integrations* section later in the document for more information.

* The connector code will be in a Github repository (public or private)
* The connector will be developed in a repository separate to any others used by your model
* The Docker images will be published automatically using Github Actions
* The Docker image will be published to Github Packages (not Github Container Registry)

## Process

1. Fork this repository
1. Obtain a copy of the latest version of the output schema: `curl https://raw.githubusercontent.com/covid-policy-modelling/model-runner/main/packages/api/schema/output.json -o output-schema.json`
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

- The command must return a non-zero status code if the simulation fails, and a zero otherwise
- The container must not require any arguments in order to carry out the simulation
  - Specify `ENTRYPOINT` or `CMD` appropriately in such a way that the container can be executed with no special arguments or other knowledge.
  - Do not specify any additional arguments in `docker-compose.yml`
- If your model requires additional data beyond that given in the input schema, either:
  - Add it your container at build-time, e.g. with `ADD`/`COPY`/`RUN`
  - Download it in your connector code
- At run-time, copy/store any input data in `/data/input` (this will be volume mounted into the container, and will be available for download in the UI after completion)
- At run-time, copy/store any output data in `/data/output` (this will be volume mounted into the container, and will be available for download in the UI after completion)
- Any messages that are printed to STDOUT will not be displayed to end-users, but can be useful for debugging in the backend.
- Any additional logging should be copied/stored in `/data/log` (this will be volume mounted into the container, but will not be available for download by default)

### Input

A file with all of the required input information will be mounted into the container as `/data/input/inputFile.json`.
This file will contain JSON that satisfies the generalized [`ModelInput` schema](https://github.com/covid-policy-modelling/model-runner/blob/main/packages/api/schema/input.json) (you can also use the [less-formal but more readable source](https://github.com/covid-policy-modelling/model-runner/blob/main/packages/api/src/model-input.ts).

Your connector code should transform this input into whichever parameters or input files your model accepts.
(If your model already accepts input in this format, the connector can simply pass it on)

Not all input parameters may be appropriate for your model, but you should make use of those you can, and document `meta.yml` accordingly.

### Output

Your container is expected to create a file: `/data/output/data.json` after the simulation.
This file should contain JSON that satisfies the generalized [`ModelOutput` schema](https://github.com/covid-policy-modelling/model-runner/blob/main/packages/api/schema/output.json) (you can also use the [less-formal but more readable source](https://github.com/covid-policy-modelling/model-runner/blob/main/packages/api/src/model-output.ts).

Your connector code should transform the output of your model into this format.
(Again, if your model already produces output in this format, the connector can simply pass it on)

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

