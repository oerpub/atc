define ['cs!gh-book/migration-utils'], (MigrationUtils) ->
  return MigrationUtils.migrateXhtmlFile ($body) ->
    # Look for tables and repair.
    $captions = $body.find('table caption')
    if $captions.length
      $captions.remove()
      return true
    return false
