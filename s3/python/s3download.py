#!/usr/bin/env python
import boto3
from pyhesity import *

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-s', '--server', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-m', '--mfacode', type=str, default=None)
parser.add_argument('-e', '--emailmfacode', action='store_true')
parser.add_argument('-v', '--viewname', type=str, required=True)
parser.add_argument('-f', '--filename', type=str, required=True)

args = parser.parse_args()

server = args.server
username = args.username
domain = args.domain
useApiKey = args.useApiKey
password = args.password
noprompt = args.noprompt
mfacode = args.mfacode
emailmfacode = args.emailmfacode
viewname = args.viewname
filename = args.filename

# authentication =========================================================
apiauth(vip=server, username=username, domain=domain, password=password, useApiKey=useApiKey, prompt=(not noprompt), mfaCode=mfacode, emailMfaCode=emailmfacode)

# exit if not authenticated
if apiconnected() is False:
    print('authentication failed')
    exit(1)
# end authentication =====================================================

user = api('get', 'sessionUser')

s3 = boto3.resource('s3',
                    endpoint_url='https://%s:3000' % server,
                    aws_access_key_id=user['s3AccessKeyId'],
                    aws_secret_access_key=user['s3SecretKey'])

bucket = s3.Bucket(viewname)

try:
    print('\nDownloading %s...' % filename)
    s3.Object(viewname, filename).download_file(filename)
except Exception as e:
    pass
print('')
