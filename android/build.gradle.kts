apply(from = "jcenter_stub.gradle")

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.0.20")
    }
}

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
    if (name == "file_picker" || name == "screen_protector") {
        plugins.apply("org.jetbrains.kotlin.android")
    }
}
subprojects {
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        kotlinOptions {
            jvmTarget = "17"
        }
    }
}

subprojects {
    val configureCompileSdk = {
        val android = project.extensions.findByName("android")
        if (android != null) {
            try {
                val setCompileSdk = android.javaClass.getMethod("setCompileSdk", java.lang.Integer.TYPE)
                setCompileSdk.invoke(android, 36)
                println("Force compileSdk 36 on ${project.name}")
            } catch (e: Exception) {
                try {
                    val compileSdkVersion = android.javaClass.getMethod("compileSdkVersion", java.lang.Integer.TYPE)
                    compileSdkVersion.invoke(android, 36)
                    println("Force compileSdkVersion 36 on ${project.name}")
                } catch (e2: Exception) {
                    // Ignore
                }
            }
        }
    }
    if (project.state.executed) {
        configureCompileSdk()
    } else {
        project.afterEvaluate {
            configureCompileSdk()
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
