from pathlib import Path
p=Path(__file__).resolve().parents[1]/"project.yml"
s=p.read_text(encoding="utf-8")
s=s.replace("      - target: DavLauncherAction\n        embed: true", "      - target: DavLauncherAction\n        embed: true\n      - target: DavLauncherSiriPanelUI\n        embed: true")
block="""  DavLauncherSiriPanelUI:
    type: app-extension
    platform: iOS
    sources:
      - path: Sources/SiriPanelUI
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: $(APP_BUNDLE_ID).SiriPanelUI
        PRODUCT_MODULE_NAME: DavLauncherSiriPanelUI
        PRODUCT_NAME: DavLauncherSiriPanelUI
        INFOPLIST_FILE: Config/SiriPanelUI-Info.plist
        GENERATE_INFOPLIST_FILE: NO
        SKIP_INSTALL: YES
        APPLICATION_EXTENSION_API_ONLY: YES

"""
s=s.replace("  DavLauncherTests:\n",block+"  DavLauncherTests:\n")
s=s.replace("        DavLauncherAction: all\n","        DavLauncherAction: all\n        DavLauncherSiriPanelUI: all\n")
p.write_text(s,encoding="utf-8")
