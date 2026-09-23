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
    
    val setNdkVersion = Action<Project> {
        if (hasProperty("android")) {
            val android = extensions.findByName("android")
            try {
                android?.let {
                    val method = it::class.java.getMethod("setNdkVersion", String::class.java)
                    method.invoke(it, "29.0.14206865")
                }
            } catch (e: Exception) { }
        }
    }

    // التحقق من حالة المشروع قبل إضافة المستمع
    if (state.executed) {
        setNdkVersion.execute(project)
    } else {
        afterEvaluate {
            setNdkVersion.execute(project)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
