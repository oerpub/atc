# Migration Framework

The purpose of the migration framework is to easily create tasks by which you
can modify the content of a book in bulk.

## Components

The migration framework consists of a view implemented in
`scripts/gh-book/migration.coffee`, some utility and helper functions in
`scripts/gh-book/migration-utils.coffee`, and migration tasks in
`scripts/migrations`.

## Invoking a migration task

Once you have a book loaded, the edit view will be open on the first module in
that book, eg:

    http://localhost:8080/#repo/shelf/book/edit/1.html|toc.opf

Modify the url so as to invoke the migration view, and pass a migration task
to run, for example to remove captions from tables:

    http://localhost:8080/#repo/shelf/book/migrate/tables

## Creating your own migration task

Create a coffeescript file in `scripts/migrations`. This script should use
require.js to define and return a single callable/function. This function
itself takes a single parameter, a module. It should return a promise.

The migration framework will iterate through all modules in the book and pass
them to your migration function one by one. It is your own responsibility to
check if the passed module is of the right type. This allows the writing of
migration tasks for any type of module, by delegating the module selection
logic to the task itself.

If there is some problem with the migration of the module, the promise should
be rejected. Otherwise the promise should be resolved with another parameter,
which is either 'skipped' or 'completed'. You should pass 'skipped' if the
passed module is not of a type you want to migrate. Upon successful migration,
resolve the promise with the 'completed' parameter.

## Helper utils

Presently there is only one util: A factory function that creates simple
migrations specifically for xhtml modules.

### Xhtml helper

Because the majority of migrations are expected to be changes to the xhtml
content of a book, you will find in `scripts/gh-book/migration-utils.coffee`
a factory method that uses a callback to create a migration function. This
utility will automatically skip non-xhtml modules, fetch the rest, parse them
and construct a document object. It will then call the provided callback
function and pass the jquery-wrapped document as a parameter. The job of the
callback is to change the passed jquery object, and then return true if any
changes were made, false otherwise.

This allows very simple xhtml migrations to be written, for example:

    define ['cs!gh-book/migration-utils'], (MigrationUtils) ->
      return MigrationUtils.migrateXhtmlFile ($body) ->
        # Add listing class to tables
        $tables = $body.find('table')
        if $tables.length
          $tables.addClass('listing')
          return true
        return false

## Existing migrations
* tables: Scans all xhtml documents and remove captions from tables.
* head: Looks for documents with `<head>undefined</head>`, caused by another
  bug in the code, and remove it.
