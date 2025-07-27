// android/build.gradle.kts  <--- Make sure you edit THIS file at the top level of the 'android' folder

// *** THIS ENTIRE BUILDSCRIPT BLOCK IS NEEDED ***
buildscript {
    // Define Kotlin version using 'val' and double quotes for the string
    val kotlin_version = "1.8.22" // Match version in settings.gradle.kts

    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Use classpath("group:name:version") syntax for dependencies
        classpath("com.android.tools.build:gradle:8.7.0") // Match version in settings.gradle.kts
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlin_version")
        classpath("com.google.gms:google-services:4.4.1") // Google Services classpath
    }
}
// *** END OF BUILDSCRIPT BLOCK ***

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Your existing build directory redirection logic is fine
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Your existing clean task is fine
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
