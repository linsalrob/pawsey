"""
Given a SRA project ID for an assembly, trace it out to get all the fastq files
"""

import os
import sys
import argparse
import requests
import urllib.request

__author__ = 'Rob Edwards'


def get_sample_accessions(project_id, verbose=False):
    """
    Convert the project ID to a list of sample accessions
    """

    # https://www.ebi.ac.uk/ena/portal/api/filereport?accession=PRJEB43974&result=analysis&fields=study_accession,sample_accession&format=json&download=true&limit=0
    url = f"https://www.ebi.ac.uk/ena/portal/api/filereport?accession={project_id}&result=analysis&fields=study_accession,sample_accession&format=json&download=true&limit=0"
    r = requests.get(url)

    if r.status_code != 200:
        print(f"Error getting url for {project_id}\nURL: {url}\nError: {r.status_code}", file=sys.stderr)
        return []
    if verbose:
        print(f"Response code: {r.status_code} for {project_id}", file=sys.stderr)
    accs = set()
    for resp in r.json():
        accs.add(resp['sample_accession'])
    return accs

def get_fastq_links(accs, verbose=False):
    """
    Get a list of the fastq links for all of the samples in accs
    """

    runs = {}
    for acc in accs:
        if verbose:
            print(f"Getting fastq URLs for {acc}", file=sys.stderr)
        
        url = f"https://www.ebi.ac.uk/ena/portal/api/filereport?accession={acc}&result=read_run&fields=study_accession,sample_accession,run_accession,fastq_ftp&format=json&download=true&limit=0"
        r = requests.get(url)
        if r.status_code != 200:
            print(f"Error getting url for accessions {acc}\nURL: {url}\nERROR: {r.status_code}", file=sys.stderr)
            continue
        for resp in r.json():
            runs[resp['run_accession']] = resp['fastq_ftp'].split(";")
    return runs

def download_fastq_files(runs, directory, verbose=False):
    """
    Download the individual fastq files and store them in directory
    """

    os.makedirs(directory, exist_ok=True)
    for ra in runs:
        for ftp in runs[ra]:
            if ftp.startswith('ftp://'):
                url = ftp
            else:
                url = f"ftp://{ftp}"

            filename = ftp.split("/")[-1]
            
            if verbose:
                print(f"Getting {url} and storing in {filename}", file=sys.stderr)

            urllib.request.urlretrieve(url, os.path.join(directory, filename))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=' ')
    parser.add_argument('-p', help='project ID', required=True)
    parser.add_argument('-d', help='download fastq files')
    parser.add_argument('-v', help='verbose output', action='store_true')
    args = parser.parse_args()

    accs = get_sample_accessions(args.p, args.v)
    print(accs)
    runs = get_fastq_links(accs, args.v)
    print(runs)
    if args.d:
        download_fastq_files(runs, args.d, args.v)
