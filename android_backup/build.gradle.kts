// Top-level build file
buildscript {
    dependencies {
        // ADD this Firebase dependency
        classpath("com.google.gms:google-services:4.3.15")
        dependencies {
        classpath 'com.android.tools.build:gradle:8.1.2'
}

    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Firebase requires a custom build directory setup
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
