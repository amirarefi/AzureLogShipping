This powershell script can be used to export/ship iis logs from local web server to azure blob storage.

The script connects to the blob storage using SAS tokens. It will then identify the most recent files that are likely to be locked by the iis process, copy them to another folder and export them to azure.

Subsequently, the script will shipp other recent files available in the iis logs folder.

For full details visit amiraref.com
