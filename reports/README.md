# Reports

Various Scripts to generate reports

## About Reporting on Object Level Backup History

Using API scripts, object level history only goes back as far as the local retention period (object level history is pruned from the API upon snapshot expiry).

To get older object level history, we must use PostgreSQL or Helios as the data source.

### Using PostgreSQL

The following scripts can run a PostgreSQL query and export the results to a spreadsheet:

* For PowerShell: <https://github.com/bseltz-cohesity/scripts/tree/master/groot/powershell/grootQuery>
* For Python: <https://github.com/bseltz-cohesity/scripts/tree/master/groot/python/grootQuery>

Both take a .sql file as input. You can use one of the following example queries:

<https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/groot/queries/objectProtectionHistory.sql>

Or a more detailed:

<https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/groot/queries/objectProtectionDetails.sql>

### Using Helios

These scripts gather Helios reports and export to a spreadsheet:

* For PowerShell: <https://github.com/bseltz-cohesity/scripts/tree/master/reports/heliosV2/powershell/heliosReport>
* For Python: <https://github.com/bseltz-cohesity/scripts/tree/master/reports/heliosV2/python/heliosReport>