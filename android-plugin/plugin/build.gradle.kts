plugins {
	id("com.android.library")
	id("org.jetbrains.kotlin.android")
}

// Must match the Godot editor you export with.
val godotVersion = "4.7.0.stable"
val pluginName = "LauncherPlugin"
val addonBin = file("../../godot/addons/socket_launcher/bin")

android {
	namespace = "com.khaled.socketlauncher"
	compileSdk = 35

	defaultConfig {
		minSdk = 24
	}
	compileOptions {
		sourceCompatibility = JavaVersion.VERSION_17
		targetCompatibility = JavaVersion.VERSION_17
	}
	kotlinOptions {
		jvmTarget = "17"
	}
	sourceSets.named("main") {
		java.srcDirs("src/main/kotlin")
	}
}

dependencies {
	compileOnly("org.godotengine:godot:$godotVersion")
}

// Drop the built AARs straight into the Godot addon, where the export plugin
// looks for them.
val copyDebugAar by tasks.registering(Copy::class) {
	from("build/outputs/aar")
	include("plugin-debug.aar")
	rename { "$pluginName-debug.aar" }
	into(addonBin.resolve("debug"))
}
val copyReleaseAar by tasks.registering(Copy::class) {
	from("build/outputs/aar")
	include("plugin-release.aar")
	rename { "$pluginName-release.aar" }
	into(addonBin.resolve("release"))
}
tasks.matching { it.name == "assemble" }.configureEach {
	finalizedBy(copyDebugAar, copyReleaseAar)
}
