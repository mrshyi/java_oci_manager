# Security policy

Do not report exposed cloud credentials, private keys, or access tokens in a
public issue. Revoke the credential first, then use GitHub private vulnerability
reporting. If that feature is unavailable, open a sanitized issue requesting a
private contact channel without including the credential or sensitive logs.

This repository packages a third-party native executable. Vulnerabilities in
R-Bot itself should also be reported to the upstream project:
https://github.com/semicons/java_oci_manage.

Container-build issues, workflow vulnerabilities, and accidental secret
exposure caused by this repository belong here. Include the image digest,
architecture, tag, reproduction steps, and sanitized logs when possible.

