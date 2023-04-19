import os, re, json
from argparse import ArgumentParser
from urllib import parse
from urllib.request import Request, urlopen
from urllib.error import HTTPError



azdo_url = os.getenv('azdoUrl')
b64_token = os.getenv('AZDO_PAT_B64')


def update_markdown(page_name: str, from_date: str, to_date: str, branch: str, func: str) -> None:
    api_path = parse.quote('Release changelog - API')
    yr_month = parse.quote(page_name)
    wiki_url = f'https://{azdo_url}/_apis/wiki/wikis/projecting.wiki/pages?path=/{api_path}/{yr_month}&includeContent=True&api-version=6.0'
    func_uri = os.getenv('AzFuncUri')
    func_code = os.getenv('FUNC_CODE')
    if func == 'companyadofunctionsapplx':
        func_uri = os.getenv('AzFuncUriLx')
        func_code = os.getenv('FUNC_CODE_LX')

    azfunc_url = f'{func_uri}GetWorkItemsFunction?from={from_date}&to={to_date}&branch={branch}&code={func_code}'
    md_resp = urlopen(Request(azfunc_url)).read().decode('utf-8')
    print(md_resp)

    if len(re.findall('[0-9]{5,}', md_resp)) > 0:
        headers = {
            'Authorization': f'Basic {b64_token}',
            'Content-Type': 'application/json'
        }
        try:
            is_created = True
            wiki_resp = urlopen(Request(wiki_url, headers=headers))
        except HTTPError as e:
            if e.code == 404:
                is_created = False
            else:
                raise Exception('wiki page http request failed') from e
        finally:
            if is_created:
                headers.update({'If-Match': wiki_resp.headers['ETag']})
            body = { 'content': md_resp }
            md_payload = json.dumps(body).encode('utf-8')
            put_resp = urlopen(Request(wiki_url, headers=headers, data=md_payload, method='PUT'))
            print(put_resp.code, put_resp.msg)


if __name__ == '__main__':
    parser = ArgumentParser(description='wiki markdown parameters', exit_on_error=True)
    parser.add_argument('--page-name', required=True)
    parser.add_argument('--from-date', required=True)
    parser.add_argument('--to-date', required=True)
    parser.add_argument('--release-branch', required=True)
    parser.add_argument('--az-func', required=True, choices=('companyadofunctions','companyadofunctionsapplx'))
    args = parser.parse_args()
    update_markdown(
        page_name = args.page_name,
        from_date = args.from_date,
        to_date = args.to_date,
        branch = args.release_branch,
        func = args.az_func
    )