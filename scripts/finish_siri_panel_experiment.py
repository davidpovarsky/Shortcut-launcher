from pathlib import Path
p=Path(__file__).resolve().parents[1]/"project.yml"
s=p.read_text(encoding="utf-8")
s=s.replace("      - target: DavLauncherSiriPanelUI\n        embed: true","      - target: DavLauncherSiriPanelUI\n        embed: true\n      - target: DavLauncherSiriPanelHandler\n        embed: true")
s=s.replace("      - path: Sources/SiriPanelUI\n","      - path: Sources/SiriPanelUI\n      - path: Config/DavShowPanel.intentdefinition\n")
block="""  DavLauncherSiriPanelHandler:
    type: app-extension
    platform: iOS
    sources:
      - path: Sources/SiriPanelHandler
      - path: Config/DavShowPanel.intentdefinition
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: $(APP_BUNDLE_ID).SiriPanelHandler
        PRODUCT_MODULE_NAME: DavLauncherSiriPanelHandler
        PRODUCT_NAME: DavLauncherSiriPanelHandler
        INFOPLIST_FILE: Config/SiriPanelHandler-Info.plist
        GENERATE_INFOPLIST_FILE: NO
        SKIP_INSTALL: YES
        APPLICATION_EXTENSION_API_ONLY: YES

"""
s=s.replace("  DavLauncherTests:\n",block+"  DavLauncherTests:\n")
s=s.replace("        DavLauncherSiriPanelUI: all\n","        DavLauncherSiriPanelUI: all\n        DavLauncherSiriPanelHandler: all\n")
p.write_text(s,encoding="utf-8")
