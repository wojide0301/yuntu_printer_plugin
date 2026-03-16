buildscript {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.2.2")
    }
}

apply(plugin = "com.android.library")

group = "com.yuntu.printer.plugin.yuntu_printer_plugin"
version = "1.0"

configure<com.android.build.gradle.LibraryExtension> {
    namespace = "com.yuntu.printer.plugin.yuntu_printer_plugin"
    compileSdk = 34

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        minSdk = 24
    }

    testOptions {
        unitTests.all {
            it.outputs.upToDateWhen { false }
            it.testLogging {
                events("passed", "skipped", "failed", "standardOut", "standardError")
                showStandardStreams = true
            }
        }
    }
}

repositories {
    google()
    mavenCentral()
}

dependencies {
    add("testImplementation", "junit:junit:4.13.2")
    add("testImplementation", "org.mockito:mockito-core:5.0.0")
}
