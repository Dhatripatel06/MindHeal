import org.jetbrains.kotlin.gradle.tasks.KotlinCompile


buildscript {
    repositories {
        google()
        mavenCentral()
       
        maven { setUrl("https://maven.aliyun.com/repository/public") }
        
    }
    dependencies {
    classpath("com.android.tools.build:gradle:8.9.1")  // Updated for Health Connect compatibility
        classpath(kotlin("gradle-plugin", version = "2.1.0"))
        
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
        maven("https://jitpack.io")
    }
}


rootProject.buildDir = file("../build")

subprojects {
    project.buildDir = file("${rootProject.buildDir}/${project.name}")
}

 tasks.withType<JavaCompile> {
    options.compilerArgs.addAll(listOf("-Xlint:none", "-nowarn"))
}

tasks.register<Delete>("clean") {
    delete(rootProject.buildDir)
}

tasks.withType<KotlinCompile>().configureEach {
    kotlinOptions {
        jvmTarget = "17"
    }
}
tasks.withType<JavaCompile>().configureEach {
    options.release.set(17)
}


