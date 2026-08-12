allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // Some plugins (e.g. `printing`) ship an Android module whose own
    // build.gradle hardcodes an old compileSdkVersion (30), which no longer
    // satisfies the compileSdk >= 34 requirement of their own transitive
    // AndroidX dependencies (fragment, lifecycle, core-ktx, etc.), causing
    // `checkDebugAarMetadata` to fail. That hardcoded value is set inside
    // the plugin's own android {} block, which runs *after* a
    // `plugins.withId` callback fires, so we must re-apply our override
    // once the whole subproject script has finished evaluating instead.
    afterEvaluate {
        extensions.findByType(com.android.build.gradle.LibraryExtension::class.java)?.compileSdkVersion(36)
        extensions.findByType(com.android.build.gradle.AppExtension::class.java)?.compileSdkVersion(36)
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
