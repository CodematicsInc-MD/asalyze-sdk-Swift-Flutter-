#if UNITY_IOS
using UnityEditor;
using UnityEditor.Callbacks;
using UnityEditor.iOS.Xcode;

/// <summary>
/// Post-build tweaks so the Swift Asalyze pod links cleanly into the Unity-generated Xcode project:
/// enables Swift on the targets (so the Swift runtime is linked + embedded) and turns off bitcode.
/// EDM4U handles the `pod install` itself; this only sets the build settings CocoaPods can't.
///
/// NOTE: the `.mm` shim imports &lt;Asalyze/Asalyze-Swift.h&gt;, which needs the pod integrated as a
/// framework. If your project links pods statically, enable "Add use_frameworks" in EDM4U's iOS
/// Resolver settings (or add `use_frameworks!` to the Podfile). See the package README.
/// </summary>
public static class AsalyzeBuildPostProcessor
{
    [PostProcessBuild(100)]
    public static void OnPostProcessBuild(BuildTarget target, string path)
    {
        if (target != BuildTarget.iOS) return;

        string projPath = PBXProject.GetPBXProjectPath(path);
        var proj = new PBXProject();
        proj.ReadFromFile(projPath);

        string main = proj.GetUnityMainTargetGuid();
        string framework = proj.GetUnityFrameworkTargetGuid();

        foreach (string guid in new[] { main, framework })
        {
            proj.SetBuildProperty(guid, "SWIFT_VERSION", "5.0");
            proj.SetBuildProperty(guid, "CLANG_ENABLE_MODULES", "YES");
            proj.SetBuildProperty(guid, "ENABLE_BITCODE", "NO");
        }
        // The Swift standard library must ship with the app since the main target is otherwise ObjC/C++.
        proj.SetBuildProperty(main, "ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES", "YES");

        // The privacy manifest has to be a BUNDLE RESOURCE, not merely present. Unity copies files from
        // Plugins/iOS into the generated project, but an unrecognised extension is added without being
        // put in Copy Bundle Resources — so the file would sit in the project and never ship, and the
        // failure is silent: the app builds, uploads, and Apple reports an undeclared API anyway.
        //
        // SPM, CocoaPods and Flutter all bundle theirs declaratively. Unity is the one host where it
        // takes code, so it is done here rather than left to chance.
        const string manifest = "Libraries/Asalyze/Plugins/iOS/PrivacyInfo.xcprivacy";
        string manifestGuid = proj.FindFileGuidByProjectPath(manifest);
        if (manifestGuid == null)
        {
            // Package layout differs between a .unitypackage import and UPM; fall back to a scan rather
            // than guessing a second hard-coded path.
            foreach (string candidate in System.IO.Directory.GetFiles(path, "PrivacyInfo.xcprivacy", System.IO.SearchOption.AllDirectories))
            {
                string rel = candidate.Substring(path.Length).TrimStart('/', '\\').Replace('\\', '/');
                manifestGuid = proj.FindFileGuidByProjectPath(rel) ?? proj.AddFile(candidate, rel, PBXSourceTree.Source);
                break;
            }
        }
        if (manifestGuid != null) proj.AddFileToBuild(main, manifestGuid);

        proj.WriteToFile(projPath);
    }
}
#endif
