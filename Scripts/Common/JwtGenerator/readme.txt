JwtGenerator - V.1.0.0.0

A commandline tool to generate a JWT.

OPTIONS:

        tokenid         The tokenId to use. Must be valid GUID string. Example: /tokenid=[GUID] (OPT)
        cert            The signing certificate thumbprint value. Example: /cert=[Cert thumbprint]
        cnty            Country(cnty) claim value. Example: /cnty=DK (OPT)
        chnl            Channel(chnl) claim value. Example: /chnl=test (OPT)
        iss             Issuer(iss) claim value. Example: /iss=companyTest
        aud             Audience(aud) claim value. Example: /aud=urn:company-Test
        client          Client claim value. Example: /client=[RegNr] (OPT)
        sub             Subject(sub) claim value. Defaults to application user. Example: /sub=[UserId|CallerId] (OPT)
        valid           Valid before seconds - to set nbf claim value. Example: /valid=60 (default=120)
        exp             Expire time in seconds - to set exp claim value. Example: /exp=120 (default=300)
        custom          Custom claims list. Seperator = '|'. Example: /claims:claim1=val1|claim2=val2|claim3=val3

USAGE:

JwtGenerator.exe  [/?]
                  [/tokenid=GUID]
                  /cert=CERT-THUMBPRINT
                  /cnty=COUNTRY
                  /chnl=CHANNEL
                  /iss=ISSUER
                  /aud=AUDIENCE
                  /client=CLIENT|REGNR
                  [/sub=USER|CALLER]
                  /valid=SECS-BEFORE
                  /exp=SECS-TIL-EXPIRE
                  /custom=CUSTOM_CLAIMS_LIST

EXAMPLE:

JwtGenerator.exe /cert=CERT-THUMBPRINT /cnty=DK /chnl=test /iss=testIss /aud=testAud /client=9999 /sub=T1234567 /valid=60 /exp=300 /custom=claim1=val1|claim2=val2

prerequisites:

.NET Framework 4.6
An installed certificate with private key