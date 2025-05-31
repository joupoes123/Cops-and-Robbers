document.addEventListener('DOMContentLoaded', function () {
    const bountyBoard = document.getElementById('bounty-board');
    const bountyList = document.getElementById('bounty-list');
    const closeButton = document.getElementById('close-bounty-btn');

    // Function to update the bounty list in the UI
    function updateBountyList(bounties) {
        if (!bountyList) return;
        bountyList.innerHTML = ''; // Clear existing bounties

        if (!bounties || Object.keys(bounties).length === 0) {
            const li = document.createElement('li');
            li.className = 'no-bounties';
            li.textContent = 'No active bounties.';
            bountyList.appendChild(li);
            return;
        }

        for (const playerId in bounties) {
            if (bounties.hasOwnProperty(playerId)) {
                const data = bounties[playerId];
                const li = document.createElement('li');

                const currentTimeSeconds = Math.floor(Date.now() / 1000);
                const expiresInSeconds = data.expiresAt - currentTimeSeconds;
                let formattedTimeRemaining = "Expired";

                if (expiresInSeconds > 0) {
                    const minutes = Math.floor(expiresInSeconds / 60);
                    const seconds = expiresInSeconds % 60;
                    formattedTimeRemaining = `${minutes}:${seconds < 10 ? '0' : ''}${seconds}`;
                }

                li.innerHTML = `
                    <strong>Target:</strong> ${escapeHtml(data.name || 'Unknown')} <br>
                    <strong>Bounty:</strong> $${formatNumber(data.amount || 0)} <br>
                    <strong>Expires In:</strong> ${formattedTimeRemaining}
                `;
                // Potentially add more details like issueTimestamp if needed, converted to readable format
                bountyList.appendChild(li);
            }
        }
    }

    // Listen for NUI messages from client.lua
    window.addEventListener('message', function (event) {
        const item = event.data;
        if (!item) return;

        if (item.action === 'showBountyBoard') {
            if (bountyBoard) bountyBoard.style.display = 'block'; // Or 'flex' if you used flex for centering menu
            updateBountyList(item.bounties);
        } else if (item.action === 'hideBountyBoard') {
            if (bountyBoard) bountyBoard.style.display = 'none';
        } else if (item.action === 'updateBountyList') {
            updateBountyList(item.bounties);
        }
    });

    // Handle close button click
    if (closeButton) {
        closeButton.addEventListener('click', function () {
            if (bountyBoard) bountyBoard.style.display = 'none';
            // Send message back to client.lua to release NUI focus
            fetch(`https://${resourceName}/closeBountyNUI`, { // Use dynamic resourceName
                method: 'POST',
                headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                body: JSON.stringify({})
            }).catch(err => console.error("NUI callback error: " + err));
        });
    }

    // Helper to escape HTML to prevent XSS
    function escapeHtml(unsafe) {
        if (typeof unsafe !== 'string') {
            // If it's not a string, try to convert it or return a placeholder
            return String(unsafe);
        }
        return unsafe
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
            .replace(/"/g, "&quot;")
            .replace(/'/g, "&#039;");
    }

    // Helper to format numbers with commas
    function formatNumber(num) {
        return num.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",");
    }

});

// It's good practice to ensure GetParentResourceName() is available if using it.
// For FiveM NUI, the resource name is usually hardcoded or passed from Lua if needed for the fetch URL.
// The example uses 'cnr_gamemode' as the resource name. Change if yours is different.
const resourceName = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'cnr_gamemode';

// Modify the fetch URL to use the dynamic or hardcoded resource name
// This was already done in the closeButton event listener, but good to be mindful.
// fetch(`https://${resourceName}/closeBountyNUI`, { ... });
