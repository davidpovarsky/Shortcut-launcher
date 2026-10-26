from pathlib import Path
r=Path(__file__).resolve().parents[1]
p=r/'project.yml'
s=p.read_text()
s=s.replace('      - path: Sources/App\n','      - path: Sources/App\n      - path: Config/DavShowPanel.intentdefinition\n',1)
p.write_text(s)
p=r/'Sources/App/AppDelegate.swift'
s=p.read_text().replace('import CoreSpotlight\n','import CoreSpotlight\nimport Intents\n',1)
s=s.replace('        DiagnosticLog.syncSharedLogToDocuments()\n        return true','        DiagnosticLog.syncSharedLogToDocuments()\n        SiriPanelDonation.donate()\n        return true',1)
p.write_text(s)
