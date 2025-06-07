const loadingBar = document.querySelector('.loading-bar');
const loadingMessage = document.querySelector('.loading-message');

const messages = [
    "Reticulating splines...",
    "Polishing handcuffs...",
    "Brewing coffee for the night shift...",
    "Checking for wanted levels...",
    "Donuts are ready...",
    "Loading city map...",
    "Warming up the engines...",
    "Briefing the K9 unit...",
    "Almost there!"
];
let messageIndex = 0;

// Function to update visuals based on progress
function updateVisuals(progress) {
    // Update loading bar
    loadingBar.style.width = progress + '%';

    // Update message
    // Change message at different thresholds of progress
    if (progress < 10) {
        loadingMessage.textContent = messages[0]; // Reticulating splines...
    } else if (progress < 20) {
        loadingMessage.textContent = messages[1]; // Polishing handcuffs...
    } else if (progress < 30) {
        loadingMessage.textContent = messages[2]; // Brewing coffee...
    } else if (progress < 40) {
        loadingMessage.textContent = messages[3]; // Checking wanted levels...
    } else if (progress < 50) {
        loadingMessage.textContent = messages[4]; // Donuts are ready...
    } else if (progress < 60) {
        loadingMessage.textContent = messages[5]; // Loading city map...
    } else if (progress < 70) {
        loadingMessage.textContent = messages[6]; // Warming up engines...
    } else if (progress < 80) {
        loadingMessage.textContent = messages[7]; // Briefing K9 unit...
    } else if (progress < 100) {
        loadingMessage.textContent = messages[8]; // Almost there!
    } else {
        loadingMessage.textContent = "Ready to join the action!";
    }
}

// Initialize with 0% progress
updateVisuals(0);
loadingMessage.textContent = "Initializing connection..."; // Initial message before progress starts

// --- FiveM NUI Event Handling (Simulated) ---
// In a real FiveM environment, you would listen for NUI messages.
// For example: window.addEventListener('message', function(event) { ... });

// Simulate receiving progress updates from FiveM
let currentProgress = 0;
const progressInterval = setInterval(() => {
    if (currentProgress < 100) {
        currentProgress += 5; // Simulate a 5% increment
        // Ensure progress doesn't exceed 100
        if (currentProgress > 100) {
            currentProgress = 100;
        }
        updateVisuals(currentProgress);
    } else {
        updateVisuals(100); // Ensure it hits 100%
        clearInterval(progressInterval);
    }
}, 500); // Simulate update every 500ms

// --- Example of how to structure NUI event listeners (for actual FiveM use) ---
/*
window.addEventListener('message', function(event) {
    if (event.data.action === 'setProgress') {
        let progress = event.data.value;
        if (progress > 100) progress = 100;
        if (progress < 0) progress = 0;
        currentProgress = progress; // Keep track if needed elsewhere
        updateVisuals(progress);
    } else if (event.data.action === 'setCustomMessage') {
        loadingMessage.textContent = event.data.message;
    }
    // Potentially add more event types for different messages or stages
});
*/

// To make the loading screen more dynamic with FiveM's actual loading process,
// you would typically have Lua scripts send NUI messages like:
// SendNUIMessage({ action = 'setProgress', value = someProgressPercentage })
// SendNUIMessage({ action = 'setCustomMessage', message = "Loading player data..." })
