#!/usr/bin/python3

import json
import argparse
from pathlib import Path



def process_results(results_json, results_dir):
    """Process rpminspect JSON and split results into individual text files.

    One inspection result per file. Also store the outcome (pass/fail)
    in a separate file.
    """
    with open(results_json, 'rb') as f:
        inspections = json.loads(f.read().decode('utf-8', 'ignore'))

        # Add default "skipped" inspection that will be returned when there are no results
        inspections['skipped'] = [
            {
                'message': 'This inspection did not run.',
                'result': 'INFO'
            }
        ]

        for inspection_name, inspection in inspections.items():

            result_str = ''

            result_str += f'\n{inspection_name}:\n'
            result_str += '-' * (len(inspection_name) + 1)
            result_str += '\n\n'

            outcomes = set()
            for index, result in enumerate(inspection):

                message = result.get('message', '')
                if message:
                    result_str += f"{index+1}) {message}\n\n"

                outcome = result.get('result', '')
                if outcome:
                    result_str += f"Result: {outcome}\n"
                    outcomes.add(outcome)

                waiver_auth = result.get('waiver authorization', '')
                if waiver_auth:
                    result_str += f"Waiver Authorization: {waiver_auth}\n"

                details = result.get('details', '')
                if details:
                    result_str += f"\nDetails:\n{details}\n"

                remedy = result.get('remedy', '')
                if remedy:
                    result_str += f"\nSuggested Remedy:\n{remedy}\n"

                result_str += '\n\n'

            # remove all good outcomes
            outcomes.discard('OK')
            outcomes.discard('INFO')
            outcomes.discard('WAIVED')

            status = 0  # success
            # the outcomes set should be empty now,
            # if all went well
            if outcomes:
                # nope, there are some failures or unknown outcomes...
                # let's fail the test
                status = 1  # failure

            result_path = Path(results_dir) / Path(inspection_name + '_result')
            with open(result_path, 'w') as output_f:
                output_f.write(result_str)

            status_path = Path(results_dir) / Path(inspection_name + '_status')
            with open(status_path, 'w') as output_f:
                output_f.write(str(status))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('resultsdir', help='directory where to store results')
    parser.add_argument('rpminspectjson', help='JSON output from rpminspect')
    args = parser.parse_args()
    process_results(args.rpminspectjson, args.resultsdir)
