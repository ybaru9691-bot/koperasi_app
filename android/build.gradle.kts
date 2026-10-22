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
}
subprojects {
    project.evaluationDependsOn(":app")
}
subprojects {
    val applyCompileSdk: (Project) -> Unit = { p ->
        val androidExt = p.extensions.findByName("android")
        if (androidExt != null) {
            try {
                androidExt.javaClass.methods.firstOrNull { it.name == "compileSdkVersion" && it.parameterTypes.size == 1 }?.invoke(androidExt, 36)
            } catch (_: Exception) {}
            try {
                androidExt.javaClass.methods.firstOrNull { it.name == "setCompileSdkVersion" && it.parameterTypes.size == 1 }?.invoke(androidExt, 36)
            } catch (_: Exception) {}
            try {
                androidExt.javaClass.methods.firstOrNull { it.name == "setCompileSdk" && it.parameterTypes.size == 1 }?.invoke(androidExt, 36)
            } catch (_: Exception) {}
        }
    }

    if (project.state.executed) {
        applyCompileSdk(project)
    } else {
        project.afterEvaluate {
            applyCompileSdk(project)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
