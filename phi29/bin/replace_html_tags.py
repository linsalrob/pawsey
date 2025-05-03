"""
Read and parse the html file and the json dictionary of old ids -> new ids and replace the tags in the file
"""

import argparse
import json
import os
import sys
import re
from bs4 import BeautifulSoup

def replace_tags_in_html(html_file_path, tag_mapping, output_file_path):
    # Read the HTML file
    with open(html_file_path, "r", encoding="utf-8") as f:
        html_content = f.read()

    # Parse with BeautifulSoup
    soup = BeautifulSoup(html_content, "html.parser")

    # Find all <script type="application/json"> tags
    json_scripts = soup.find_all("script", {"type": "application/json"})

    for script in json_scripts:
        try:
            # Parse the JSON inside the script tag
            json_data = json.loads(script.string)

            # Recursive function to replace UUIDs
            def replace_uuids(obj):
                if isinstance(obj, dict):
                    return {k: replace_uuids(v) for k, v in obj.items()}
                elif isinstance(obj, list):
                    return [replace_uuids(v) for v in obj]
                elif isinstance(obj, str):
                    # Check if it matches UUID pattern
                    if re.fullmatch(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", obj):
                        return tag_mapping.get(obj, obj)  # Replace if in mapping, otherwise keep original
                    else:
                        return obj
                else:
                    return obj

            # Replace UUIDs
            new_json_data = replace_uuids(json_data)

            # Write back modified JSON into the script tag
            script.string = json.dumps(new_json_data, indent=2)

        except Exception as e:
            print(f"⚠️ Skipping a script tag due to error: {e}")

    # Save modified HTML
    with open(output_file_path, "w", encoding="utf-8") as f:
        f.write(str(soup))

    print(f"✅ Modified HTML saved to {output_file_path}")

def main():
    parser = argparse.ArgumentParser(description="Replace UUIDs in HTML JSON with specified mappings.")
    parser.add_argument("--html", required=True, help="Path to input HTML file.")
    parser.add_argument("--raw", required=True, help="File of raw UUIDs.")
    parser.add_argument('--phi29', required=True, help="File of phi29 UUIDs.")
    parser.add_argument("--output", required=True, help="Path to output modified HTML file.")
    args = parser.parse_args()

    # read the raw UUIDs and phi29 UUIDS, and store them in tag_mapping
    tag_mapping = {}
    with open(args.raw, "r", encoding="utf-8") as f:
        tag_mapping = {x: f"{x[-4:]}-raw" for x in f.read().splitlines()}
    with open(args.phi29, "r", encoding="utf-8") as f:
        tag_mapping.update({x: f"{x[-4:]}-phi29" for x in f.read().splitlines()})

    if not os.path.exists(args.output):
        os.makedirs(os.path.dirname(args.output), exist_ok=True)

    # Run the replacement
    replace_tags_in_html(args.html, tag_mapping, args.output)

if __name__ == "__main__":
    main()

