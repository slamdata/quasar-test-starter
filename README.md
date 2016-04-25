# quasar-test-starter

A project that makes it easy to start MongoDB and Quasar while testing SlamData or the Quasar API.

Can be used as a library for other projects to make use of, via modules in `Quasar.Spawn`, or on the command line:

```
npm run start-clean
```
Will start Quasar and MongoDB with a default config and the datasets in the `data` directory.

```
npm run start
```
Will start Quasar and MongoDB without resetting the database and config.

When run as an executable, the content path `slamdata` is passed through as an option to Quasar, so making a symlink in the directory of this project to the `public/` folder in a SlamData project will enable testing of the front-end, hosted by the Quasar instance.
