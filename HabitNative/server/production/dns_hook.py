#!/opt/maybii-acme/bin/python
"""Certbot DNS hooks using Alibaba's official SDK and default credential chain.
Run with an ECS RAM role restricted to ddream.top. No credentials in App.
"""
import os
import sys
import time
from alibabacloud_alidns20150109.client import Client
from alibabacloud_alidns20150109 import models
from alibabacloud_credentials.client import Client as Credentials
from alibabacloud_credentials.models import Config as CredentialConfig
from alibabacloud_tea_openapi.models import Config

if os.environ.get('CERTBOT_DOMAIN') != 'api.ddream.top':
    raise SystemExit('unexpected ACME domain')
client = Client(Config(credential=Credentials(CredentialConfig(type='ecs_ram_role')), endpoint='alidns.cn-hangzhou.aliyuncs.com'))
if sys.argv[1] == 'auth':
    response = client.add_domain_record(models.AddDomainRecordRequest(
        domain_name='ddream.top', rr='_acme-challenge.api', type='TXT',
        value=os.environ['CERTBOT_VALIDATION'], ttl=600))
    print(response.body.record_id, flush=True)
    # DNS caches may retain negative responses; wait before CA validation.
    time.sleep(660)
elif sys.argv[1] == 'cleanup':
    record_id = os.environ.get('CERTBOT_AUTH_OUTPUT', '').strip()
    if not record_id.isdigit():
        raise SystemExit('invalid record ID; refusing deletion')
    client.delete_domain_record(models.DeleteDomainRecordRequest(record_id=record_id))
else:
    raise SystemExit('expected auth or cleanup')
