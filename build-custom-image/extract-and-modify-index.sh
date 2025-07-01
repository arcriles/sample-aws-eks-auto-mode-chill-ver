#!/bin/bash
set -e

echo "🔄 Extracting current index.html from OpenWebUI image..."

# Clean up any existing containers
docker stop temp-openwebui 2>/dev/null || true
docker rm temp-openwebui 2>/dev/null || true

# Pull the latest OpenWebUI image
echo "📦 Pulling OpenWebUI image..."
docker pull ghcr.io/open-webui/open-webui:main

# Run temporary container to extract index.html
echo "🏃 Running temporary container..."
docker run -d --name temp-openwebui ghcr.io/open-webui/open-webui:main

# Extract the original index.html
echo "📄 Extracting index.html..."
docker cp temp-openwebui:/app/build/index.html ./index-original.html

# Clean up temporary container
echo "🧹 Cleaning up temporary container..."
docker stop temp-openwebui
docker rm temp-openwebui

# Create the modified index.html
echo "✏️  Creating modified index.html with GAR GPT branding..."
cp index-original.html index.html

# Add GAR GPT branding scripts to the <head> section
# We'll insert before the closing </head> tag
cat > branding-scripts.html << 'EOF'
<script>
    // Function to update the title if it includes "Open WebUI"
    const monitorTitleChange = () => {
        // Select the <head> element, which contains the <title>
        const targetNode = document.head;

        // Create a MutationObserver to monitor changes
        const observer = new MutationObserver(() => {
            // Replace "Open WebUI" with "GAR GPT" in the document title
            if (document.title.includes("Open WebUI")) {
                document.title = document.title.replace("Open WebUI", "GAR GPT");
                console.log("Title updated to 'GAR GPT'.");
            }
        });

        // Observe the <head> for changes in child elements
        observer.observe(targetNode, {
            childList: true,
            subtree: true
        });
    };

    // Function to detect the new div and replace its class
    const monitorNewDiv = () => {
        console.log("Starting to monitor for new <div>...");

        const processDiv = () => {
            // Query the DOM for the specific <div> with required classes
            const newDiv = document.querySelector("div.w-full.h-screen");

            if (newDiv) {
                console.log("Target <div> found!");

                // Locate the child element with the target class
                const targetElement = newDiv.querySelector(".text-2xl.font-medium");
                if (targetElement) {
                    console.log("Found target element with 'text-2xl font-medium' class.");

                    // Replace the text content only if it contains "Open WebUI"
                    if (targetElement.textContent.includes("Open WebUI")) {
                        console.log("Replacing text 'Open WebUI' with 'GAR GPT'...");
                        targetElement.textContent = targetElement.textContent.replace("Open WebUI", "GAR GPT");
                    } else {
                        console.log("Target element doesn't contain 'Open WebUI'.");
                    }
                } else {
                    console.log("No element with class 'text-2xl font-medium' found inside the target <div>.");
                }
            } else {
                console.log("Target <div> not found.");
            }
        };

        // Use 'load' and a small delay to ensure the DOM is fully ready
        window.addEventListener("load", () => {
            console.log("Page fully loaded. Checking for target <div>...");
            processDiv();
        });

        // Optionally, run one additional check after a longer delay for dynamically injected content
        setTimeout(processDiv, 500);
        setTimeout(processDiv, 1000);
        setTimeout(processDiv, 1500);
        setTimeout(processDiv, 2000);
        setTimeout(processDiv, 2500);
        setTimeout(processDiv, 3000);
        setTimeout(processDiv, 3500);
        setTimeout(processDiv, 4000);
        setTimeout(processDiv, 4500);
        setTimeout(processDiv, 5000);
        setTimeout(processDiv, 5500);
        setTimeout(processDiv, 6000);
        setTimeout(processDiv, 6500);
        setTimeout(processDiv, 7000);
    };

    // Start monitoring
    monitorTitleChange();
    monitorNewDiv();
</script>

<script>
    (function() {
        // Remove existing favicon links
        var existingFavicons = document.querySelectorAll('link[rel="icon"], link[rel="shortcut icon"]');
        existingFavicons.forEach(function(favicon) {
            favicon.parentNode.removeChild(favicon);
        });

        // Add new favicon link
				var link = document.createElement('link');
				link.rel = 'icon';
				link.type = 'image/png';
				link.href = 'https://www.goldenagri.com.sg/wp-content/uploads/2016/01/cropped-favicon-2-32x32.png';
				document.head.appendChild(link);

				// Optional: Also set the shortcut icon for older browsers
				var shortcutLink = document.createElement('link');
				shortcutLink.rel = 'shortcut icon';
				shortcutLink.type = 'image/png';
				shortcutLink.href = 'https://www.goldenagri.com.sg/wp-content/uploads/2016/01/cropped-favicon-2-32x32.png';
				document.head.appendChild(shortcutLink);
    })();
</script>

<style>
.flex.w-full.text-center.items-center.justify-center.self-start.text-gray-400.dark\:text-gray-600 {
  display: none;
}
.mb-3\.5:has(a[href="https://docs.openwebui.com/"]) {
  display: none;
}
div.mb-2.text-xs.text-gray-400:has(a[href*="CONTRIBUTING.md"]) {
  display: none;
}
div.space-y-3.overflow-y-scroll.max-h-\[28rem\].lg\:max-h-full:has(a[href*="discord.gg"]) {
  display: none;
}
div.mx-auto.max-w-2xl.font-primary > div.mx-5 > div.mb-1.flex > div:first-child {
  display: none !important;
}
</style>
EOF

# Insert the branding scripts before </head> using a more robust approach
# Use awk to properly handle multi-line content insertion
awk '/<\/head>/ { 
    while ((getline line < "branding-scripts.html") > 0) {
        print line
    }
    close("branding-scripts.html")
}
{ print }' index.html > index-temp.html

# Replace the original with the modified version
mv index-temp.html index.html

# Clean up temporary file
rm branding-scripts.html

echo "✅ Modified index.html created successfully!"
echo "📋 Next steps:"
echo "   1. Ensure you have the required static assets:"
echo "      - static/gar-logo.png"
echo "      - static/splash.png"
echo "      - static/splash-dark.png"
echo "   2. Run the build script: ./build-image.sh"
echo ""
echo "🔍 Files created:"
echo "   - index-original.html (backup of original)"
echo "   - index.html (modified with GAR GPT branding)"
