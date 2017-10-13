#!/usr/bin/env python

from pymarc import Record, Field, XMLWriter, TextWriter, marcxml
import boto3
import botocore
from tqdm import tqdm, trange
import logging
from rdflib import Graph, Namespace, Literal, URIRef, RDF
from rdflib.namespace import SKOS, NamespaceManager, DCTERMS
import xml.etree.ElementTree as ET
from urllib.request import urlopen
import ssl

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

logging.basicConfig(filename='makeauth.log', level=logging.DEBUG)

print("Loading input SDF and finding unique Subjects")
unique_tcodes = []
sdfs = []
sdf = {}
f = open('eescwa09Oct2017', "r", encoding="utf-8")
for line in f:
  if ": " in line:
    key, value = line.split(": ", 1)
    if key == 'Subject':
      for tcode in value.split(','):
        if not tcode.replace(' ','') in unique_tcodes:
          unique_tcodes.append(tcode.replace(' ',''))
f.close()

print("Loading RDF/Turtle")
graph = Graph()
graph.load('unbist-20170515.ttl',format='ttl')

def auth_lookup(auth_text):
  lookup = auth_text.replace(" ","+").strip()
  lookup_url = 'https://digitallibrary.un.org/search?ln=en&cc=Thesaurus&p=150__a%3A"' + lookup + '"&f=&rm=wrd&ln=en&fti=0&sf=&so=d&rg=10&sc=0&c=Thesaurus&c=&of=xm'
  logging.debug(lookup_url)
  xml_tree = ET.parse(urlopen(lookup_url, context=ctx))
  try:
    xml_root = xml_tree.getroot()[0]
  except IndexError:
    logging.debug("The specified search term yielded 0 hits.")
    return False
  else:
    ns = {'marc':'http://www.loc.gov/MARC21/slim'}
    # There should be at least one. We are looking for an exact match...
    auth_records = xml_root.findall("marc:datafield[@tag='035']/marc:subfield[@code='a']", ns)
    logging.debug("Are these the auth codes you're looking for? " + str(auth_records))
    this_auth_code = False
    for auth_record in auth_records:
      if 'DHLAUTH' in auth_record.text:
        this_auth_code = auth_record.text

    if this_auth_code:
      logging.debug(this_auth_code + " is the code you're looking for.")
      return this_auth_code
    else:
      logging.debug("Unable to detect a DHLAUTH value in this result set.")
      return False

print("Mapping auth codes")
auth_map = {}
f = open('auth.py', 'a')
f.write("AUTHS={")
with tqdm(total=len(unique_tcodes), unit='T', unit_scale=True) as pbar:
  for tcode in unique_tcodes:
    logging.debug("Looking up " + tcode + " in RDF graph.")
    for s in graph.subjects(DCTERMS.identifier,Literal(tcode)):
      label = graph.preferredLabel(s, 'en')[0][1]
      logging.debug("Found " + label + " in graph. Looking up DHL authority code.")
      dhlauth = auth_lookup(label)
      if label and dhlauth:
        logging.debug("Found " + dhlauth + " in UNDL.")
        #auth_map[tcode] = {'label':label,'dhlauth':dhlauth,'tcode':tcode}
        f.write("'" + str(tcode) + "': " + str({'label':label.value,'dhlauth':dhlauth,'tcode':tcode}) + ",\n")
      elif label and not dhlauth:
        logging.debug("Could not find a valid DHL authority code for " + label + ". Skipping.")
      else:
        logging.debug("The tcode " + tcode + " does not map to a label.")
    pbar.update()
f.write("}")
f.close()
