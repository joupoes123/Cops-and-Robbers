const loadingBar = document.querySelector('.loading-bar');
const loadingMessage = document.querySelector('.loading-message');
let width = 0;

// List of messages to display
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

function frame() {
    if (width >= 100) {
        // Potentially hide loading screen or trigger game start here
        loadingMessage.textContent = "Ready to join the action!";
    } else {
        width++;
        loadingBar.style.width = width + '%';
        // Update message every 10% progress
        if (width % 10 === 0) {
            if (messageIndex < messages.length -1 && width < 90) { // Ensure "Almost there!" is the last message before 100%
                 loadingMessage.textContent = messages[messageIndex];
                 messageIndex++;
            } else if (width >= 90 && width < 100) {
                loadingMessage.textContent = messages[messages.length -1]; // "Almost there!"
            }
        }
        requestAnimationFrame(frame); // Continue animation
    }
}

// Start the loading animation
requestAnimationFrame(frame);

// Example of how FiveM might send load progress (for simulation)
// In a real FiveM environment, you'd use NUI events
let currentProgress = 0;
const progressInterval = setInterval(() => {
    if (currentProgress < 100) {
        currentProgress += 5; // Increment progress
        if (width < currentProgress) { // Only update if internal animation is slower
            // This part is tricky because we have two animations.
            // For a real loading screen, FiveM's NUI events are the source of truth.
            // Here, we're just simulating. Let's assume our JS animation is the primary visual.
        }
    } else {
        clearInterval(progressInterval);
    }
}, 200); // Simulate progress update every 200ms
