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
    
    // Provide a fallback 'flutter' property map for third-party plugins that access
    // 'flutter.compileSdkVersion' during Gradle evaluation before FGP runs.
    if (project.name != "app") {
        extra.set("flutter", mapOf(
            "compileSdkVersion" to 34,
            "minSdkVersion" to 21,
            "targetSdkVersion" to 34,
            "ndkVersion" to "27.0.12077973"
        ))
    }
    
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }
    
    afterEvaluate {
        if (project.hasProperty("android")) {
            (project.extensions.findByName("android") as? com.android.build.gradle.BaseExtension)?.apply {
                compileOptions {
                    sourceCompatibility = JavaVersion.VERSION_17
                    targetCompatibility = JavaVersion.VERSION_17
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
