"""
Given a SRA project ID for an assembly, trace it out to get all the fastq files
"""

import os
import shutil
import sys
import argparse
import requests
import urllib.request

__author__ = 'Rob Edwards'


def get_sample_accessions(project_id, analysisacc, verbose=False):
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
    
    for resp in r.json():
        if 'analysis_accession' in resp and resp['analysis_accession'] == analysisacc:
            return {resp['sample_accession']}
    
    raise ValueError(f"ERROR: Analysis Accession {analysisacc} was not found in project {project_id}")

def get_all_accs(project_id, verbose=False):
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
            raise requests.exceptions.RequestException(f"Error getting url for accessions {acc}\nURL: {url}\nERROR: {r.status_code}")
            
        for resp in r.json():
            runs[resp['run_accession']] = resp['fastq_ftp'].split(";")
    return runs

def download_fastq_files(runs, localdirectory, directory, verbose=False):
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
            
            if os.path.exists(os.path.join(localdirectory, filename)):
                print(f"Copying local file {filename} from {localdirectory}", file=sys.stderr)
                # shutil.copy(os.path.join(localdirectory, filename), os.path.join(directory, filename))
                os.link(os.path.join(localdirectory, filename), os.path.join(directory, filename))
            else:
                print(f"Forcing download from {url} and storing in {filename}", file=sys.stderr)
                urllib.request.urlretrieve(url, os.path.join(localdirectory, filename))
                # shutil.copy(os.path.join(localdirectory, filename), os.path.join(directory, filename))
                os.link(os.path.join(localdirectory, filename), os.path.join(directory, filename))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=' ')
    parser.add_argument('-p', help='project ID', required=True)
    parser.add_argument('-a', help='analysis accession', required=True)
    parser.add_argument('-l', help='local directory', required=True)
    parser.add_argument('-c', action='store_true',
                       help='continue if there are no fastq files identified. ' +
                        ' We copy all fastq files for that directory')
    parser.add_argument('-d', help='download fastq files')
    parser.add_argument('-v', help='verbose output', action='store_true')
    args = parser.parse_args()

    accs = set()
    try:
        accs = get_sample_accessions(args.p, args.a, args.v)
    except ValueError:
        if args.c:
            print(f"ERROR: Accession {args.a} not found in project {args.p}. Getting all fastqs",
                  file=sys.stderr)
            accs = get_all_accs(args.p, args.v)
        else:
            print(f"ERROR: Accession {args.a} was not found in project {args.p}", file=sys.stderr)
            exit(2)

    if args.v:
        print(f"Accession {accs}", file=sys.stderr)
    
    runs = get_fastq_links(accs, args.v)
    if args.v:
        print(f"Fastq links: {runs}", file=sys.stderr)
    if args.d:
        download_fastq_files(runs, args.l, args.d, args.v)
