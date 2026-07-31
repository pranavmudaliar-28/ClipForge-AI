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

    // Some plugins pin an older compileSdk (e.g. file_picker 8.x → android-34)
    // while others (flutter_plugin_android_lifecycle) require 36. Force every
    // Android library subproject up to 36 so AAR metadata checks pass. Registered
    // here (before evaluationDependsOn triggers evaluation) and via reflection to
    // stay agnostic to AGP's DSL surface.
    afterEvaluate {
        val androidExt = extensions.findByName("android") ?: return@afterEvaluate
        try {
            val current = androidExt.javaClass.methods
                .firstOrNull { it.name == "getCompileSdkVersion" && it.parameterCount == 0 }
                ?.invoke(androidExt) as? String
            val api = current?.substringAfter("android-", "")?.toIntOrNull()
            if (api == null || api < 36) {
                androidExt.javaClass.methods
                    .firstOrNull { it.name == "compileSdkVersion" && it.parameterCount == 1 && it.parameterTypes[0] == String::class.java }
                    ?.invoke(androidExt, "android-36")
            }
        } catch (_: Exception) {
            // Subproject without a compatible android extension — skip.
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
