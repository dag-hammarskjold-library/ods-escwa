# ods-escwa

* Objective: Complete the DLS ESCWA official documents collection.
* Context: Docs and their basic metadata are in ODS. Records for some of those docs are already in DLS 
* Execution: Create new DLS records for documents that are not already in DLS; update existing DLS records with new data/files found in ODS.

<h1> Steps </h1>

1. **scripts/compare.pl** - uses DLS data and ODS data to determine what what records are missing from the DLS, and what files are missing from existing records
    * inputs: 
        * **data/dls.tsv** - DLS "excel export" file w/ fields 001,191__a (modified to tsv)
        * **data/ods.csv** - ODS csv export of symbols 
    * output:
        * **data/in_dls.tsv** - contains symbol, DLS record id, and boolean denoting whether or not sym was found in ODS - *(did not actually end up using this for anything)*
        * **data/in_ods.tsv** - contains symbol, DLS record id (if exists), missing files (if any)
2. Manually spot-check comparison results for accuracy, edit compare script and redo results as necesary. 
3. **scripts/download.pl** - uses results from previous script to download ODS files missing from DLS to local machine
    * inputs:
        * **data/in_ods.tsv**
    * output:
        * file directory of folders named by record id, containg the downloaded files for that record
4. Upload the downloaded file directory to the cloud (s3) so they can be harvested by DLS on import of the susbsequent metadata XML
5.  **scripts/to_marc.pl** - creates two MARC XML files for import to DLS (one for new records, run in "Insert" mode in the DLS import module; one for updating records conting only fields to append to exisitng records run in "Update" mode).
    * inputs:
        * **data/in_ods.tsv**
        * **data/escwa_s3.txt** - list of s3 files created by running `ls` command in AWS CLI https://aws.amazon.com/cli/
        * **data/EESCWAST** - ODS "structured text" export containing all ODS data for ESCWA docs
    * output:
        * **output/new.xml**
        * **output/update.xml**
        
        
