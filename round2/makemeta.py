#!/usr/bin/env python

from pymarc import Record, Field, XMLWriter, TextWriter, marcxml
import boto3
import botocore
from tqdm import tqdm, trange
import logging
import xml.etree.ElementTree as ET
from urllib.request import urlopen
import ssl
from auth import AUTHS
from languages import resolve_lang

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

ns = open('escwa_new','r').readlines()

logging.basicConfig(filename='app.log', level=logging.DEBUG)

sdfs = {}
sdf = {}
f = open('eescwa09Oct2017', "r", encoding="utf-8")
for line in f:
  if ": " in line:
    key, value = line.split(": ", 1)
    sdf[key] = value.strip()
  else:
    if len(sdf) > 0:
      for sym in sdf['ALLDS'].split(','):
        sdfs[sym.replace(' ','')] = sdf
    sdf = {}
f.close()

records = []

s3_base = "https://s3.amazonaws.com/un-digital-library/"

print("Making records")
# Make links like https://s3.amazonaws.com/un-digital-library/escwa/files/E_ESCWA_1999_WG.1_13-EN.pdf
with tqdm(total=len(ns), unit='R', unit_scale=True) as pbar:
  for n in ns:
    this_sym = n.strip()
    this_fn_base = 'escwa/files/' + this_sym.replace('/','_')
    this_fn = this_fn_base

    record = Record()
    if 'E/ESCWA' in this_sym:
      record.add_field(Field(tag = '191', indicators=[' ',' '], subfields=['0','972209','a',this_sym,'b','E/ESCWA/']))
    else:
      record.add_field(Field(tag = '191', indicators=[' ',' '], subfields=['a',this_sym,]))

    # find the record from the ODS data
    ods_record = ''
    try:
      ods_record = sdfs[this_sym.replace(' ','')]
    except KeyError:
      logging.debug(this_sym + " could not be found in ODS data.")
    else:
      logging.debug("Found " + this_sym)
      #Subject => \&_650,
      # Get the English title
      title_e = ods_record['Title']
      if len(title_e) > 0:
        record.add_field(Field(tag = '245',indicators = ['1','0'],subfields = ['a',title_e,]))

      # Now get the rest of the titles, which go in 246
      for lang in ['A','C','F','R','S']:
        # There are cases where no English title exists, so we need something in 245, and whatever goes there gets removed from 246
        title = ods_record['Title' + lang]
        if len(title) > 0:
          if len(title_e) < 1 and not record.__contains__('245'):
            # This should just assign the first encountered title to 245, then the rest will go to 246
            record.add_field(Field(tag='245',indicators=['1','0'],subfields=['a',title]))
          else:
            record.add_field(Field(tag = '246',indicators = ['3',' '],subfields = ['a',title,])) 

      
      # Get the Job Numbers for 029 and the language codes that go in 041
      LANGS = {'A':'ara','C':'chi','E':'eng','F':'fre','R':'rus','S':'spa','O':'ger'}
      s041 = ''
      for l in ['A','C','E','F','R','S','O']:
        field_name = 'JN' + l
        jn = ods_record[field_name]
        if len(jn) > 0:
          record.add_field(Field(tag='029',indicators=[' ',' '],subfields=['a','JN','b',' '.join([jn,l])]))
          s041 += LANGS[l]
        
      record.add_field(Field(tag='041',indicators=[' ',' '],subfields=['a',s041]))

      # Default country code of $aLBN in 049
      record.add_field(Field(tag='049',indicators=[' ',' '],subfields=['a','LBN']))

      # Get the distribution code for 091
      dist_code = ods_record['Disp_Distribution']
      if len(dist_code) > 0:
        record.add_field(Field(tag='091',indicators=[' ',' '],subfields=['a',dist_code]))

      # get the PubDate
      pub_date = ods_record['PubDate'].split(' ')[0]
      d,m,y = pub_date.split('/')
      record.add_field(Field(tag = '269',indicators = [' ',' '],subfields = ['a',''.join([y,m,d]),]))

      # Resolve the subjects from the tcodes
      for tcode in ods_record['Subject'].split(','):
        #this_auth = False
        try:
          this_auth = AUTHS[tcode.replace(' ','')]
        except KeyError:
          next
        else:
          record.add_field(Field(tag='650',indicators=['0','7'],subfields=['a',this_auth['label'],'0',this_auth['dhlauth']]))
          

    s3 = boto3.resource('s3')
    for lang in ['','AR','EN']:
      this_fn = this_fn_base + "-" + lang + ".pdf"
      try:
        s3.Object('un-digital-library', this_fn).load()
      except botocore.exceptions.ClientError as e:
        next
      else:
        this_lang = resolve_lang(lang)
        record.add_field(Field(tag = 'FFT',indicators = [' ',' '],subfields = ['a',s3_base + this_fn,'d',this_lang['orig'],'n',this_sym.replace('/','_') + "-" + lang + ".pdf"]))

    # 980 as a means of tracking the batch
    record.add_field(Field(tag='980',indicators=[' ',' '],subfields=['a','escwa20171010']))

    # 989
    record.add_field(Field(tag='989',indicators=[' ',' '],subfields=['a','Documents and Publications']))

    # Add a 999 field to indicate 
    record.add_field(Field(tag='999',indicators=[' ',' '],subfields=['a','dlc20171010','b','20171010','c','c']))
    
    records.append(record)
    pbar.update()

with open('metadata.xml','wb+') as f:
  f.write(bytes('<?xml version="1.0"?>' + "\n", 'UTF-8'))
  f.write(bytes("<collection>\n",'UTF-8'))
  for record in records:
    f.write(marcxml.record_to_xml(record, encoding='utf-8'))
    f.write(bytes("\n","UTF-8"))
  f.write(bytes("</collection>",'UTF-8'))
