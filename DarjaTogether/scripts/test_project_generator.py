from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


class SpeechProjectGenerationTests(unittest.TestCase):
    def testSpeechFolderAndLocalPackageArePreservedInBothNativeTargets(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "scripts").mkdir()
            shutil.copyfile(Path(__file__).with_name("generate_project.py"), root / "scripts/generate_project.py")
            app = root / "DarjaTogether"
            (app / "Resources/SpeechModel/nested").mkdir(parents=True)
            (app / "App.swift").write_text("import Foundation\n", encoding="utf8")
            (app / "Resources/curriculum.json").write_text("{}", encoding="utf8")
            (app / "Resources/SpeechModel/config.json").write_text("{}", encoding="utf8")
            (app / "Resources/SpeechModel/nested/config.json").write_text("{}", encoding="utf8")
            smoke = root / "Packages/DarjaF5/Sources/DarjaF5Smoke"
            smoke.mkdir(parents=True)
            (smoke / "Smoke.swift").write_text("import DarjaF5\n", encoding="utf8")
            subprocess.run([sys.executable, str(root / "scripts/generate_project.py")], check=True, capture_output=True)
            project = (root / "DarjaTogether.xcodeproj/project.pbxproj").read_text(encoding="utf8")
            self.assertIn('lastKnownFileType = "folder"; path = "DarjaTogether/Resources/SpeechModel";', project)
            self.assertNotIn('SpeechModel/config.json', project)
            self.assertNotIn('SpeechModel/nested/config.json', project)
            self.assertIn('isa = XCLocalSwiftPackageReference; relativePath = "Packages/DarjaF5";', project)
            self.assertEqual(project.count('packageProductDependencies ='), 2)
            self.assertIn('com.apple.product-type.tool', project)
            self.assertTrue((root / "DarjaTogether.xcodeproj/xcshareddata/xcschemes/DarjaF5Smoke.xcscheme").is_file())


if __name__ == "__main__":
    unittest.main()
