"""Validate a decoded App Store profile and create manual export options.

The real CMS profile must first be decoded with macOS `security cms -D -i`.
No private signing material is printed or stored in the repository.
"""
import argparse
import datetime
import os
import pathlib
import plistlib
import re

BUNDLE_ID = "com.tubitak.tubitak"


def prepare(profile_path, output_path, team):
    if not re.fullmatch(r"[A-Z0-9]{10}", team):
        raise ValueError("APPLE_TEAM_ID must be the 10-character Apple team ID.")
    with open(profile_path, "rb") as stream:
        profile = plistlib.load(stream)
    entitlements = profile.get("Entitlements", {})
    prefix = profile.get("ApplicationIdentifierPrefix", [])
    if team not in profile.get("TeamIdentifier", []):
        raise ValueError("Provisioning profile belongs to a different Apple team.")
    if len(prefix) != 1 or entitlements.get("application-identifier") != prefix[0] + "." + BUNDLE_ID:
        raise ValueError("Provisioning profile must explicitly match " + BUNDLE_ID)
    if entitlements.get("com.apple.developer.team-identifier") != team:
        raise ValueError("Provisioning profile team entitlement does not match.")
    expiry = profile.get("ExpirationDate")
    if not isinstance(expiry, datetime.datetime) or expiry.replace(tzinfo=datetime.timezone.utc) <= datetime.datetime.now(datetime.timezone.utc):
        raise ValueError("Provisioning profile is missing an expiry date or has expired.")
    if "ProvisionedDevices" in profile or profile.get("ProvisionsAllDevices") or entitlements.get("get-task-allow"):
        raise ValueError("An App Store distribution profile is required, not development/ad hoc/enterprise.")
    if entitlements.get("aps-environment") != "production":
        raise ValueError("Enable Push Notifications on the App ID and regenerate the App Store profile.")
    if not profile.get("DeveloperCertificates"):
        raise ValueError("Provisioning profile has no distribution certificate.")
    if not re.fullmatch(r"[0-9A-Fa-f-]{36}", profile.get("UUID", "")):
        raise ValueError("Provisioning profile UUID is invalid.")
    options = {"method": "app-store-connect", "destination": "export", "signingStyle": "manual",
               "teamID": team, "signingCertificate": "Apple Distribution",
               "provisioningProfiles": {BUNDLE_ID: profile["UUID"]}, "manageAppVersionAndBuildNumber": False}
    with open(output_path, "wb") as stream:
        plistlib.dump(options, stream)
    if os.environ.get("GITHUB_ENV"):
        with open(os.environ["GITHUB_ENV"], "a", encoding="utf-8") as stream:
            stream.write("APPLE_PROFILE_UUID=" + profile["UUID"] + "\n")
    print("App Store profile validated for " + BUNDLE_ID + "; export options created.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("profile", type=pathlib.Path)
    parser.add_argument("output", type=pathlib.Path)
    args = parser.parse_args()
    try:
        prepare(args.profile, args.output, os.environ.get("APPLE_TEAM_ID", ""))
    except (ValueError, KeyError, plistlib.InvalidFileException) as error:
        parser.exit(1, str(error) + "\n")
