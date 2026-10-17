// Root build file. Versions live here so the module file stays short.
plugins {
	id("com.android.library") version "8.7.3" apply false
	id("org.jetbrains.kotlin.android") version "2.0.21" apply false
}

tasks.register("clean", Delete::class) {
	delete(rootProject.layout.buildDirectory)
}
