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
    val configureAndroid = { proj: Project ->
        if (proj.plugins.hasPlugin("com.android.application") ||
            proj.plugins.hasPlugin("com.android.library")) {
            proj.extensions.configure<com.android.build.gradle.BaseExtension> {
                compileSdkVersion(36)
                defaultConfig {
                    targetSdkVersion(34)
                }
            }
        }
    }
    if (state.executed) {
        configureAndroid(this)
    } else {
        afterEvaluate {
            configureAndroid(this)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
