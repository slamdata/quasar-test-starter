# quasar-test-starter

A project that makes it easy to start MongoDB and Quasar while testing SlamData or the Quasar API.

Can be used as a library in other projects via the modules in `Quasar.Spawn`, or on the command line through `npm` scripts.

## Command line usage

Running `npm install` first will set up the project so the following scripts are in a runnable state:

```
npm run start-clean
```
This will start Quasar and MongoDB with a default config and the datasets in the `data` directory.

```
npm run start
```
This will start Quasar and MongoDB without resetting the database and config. This will fail unless `start-clean` has been run at least once, as required directories will not exist on the first run of `start`.

## Hosting the SlamData front-end

When run as an executable, the content path `slamdata` is passed through as an option to Quasar, so making a symlink in the directory of this project to the `public/` folder in a SlamData project will enable testing of the front-end, hosted by the Quasar instance.
