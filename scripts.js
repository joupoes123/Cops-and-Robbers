let heistTimerInterval;

window.addEventListener('message', function(event) {
    let data = event.data;
    if (data.action === 'openRoleMenu') {
        document.getElementById('role-selection').style.display = 'block';
    } else if (data.action === 'startHeistTimer') {
        startHeistTimer(data.duration, data.bankName);
    }
});

function selectRole(role) {
    fetch(`https://${GetParentResourceName()}/selectRole`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({ role: role })
    });
    document.getElementById('role-selection').style.display = 'none';
}

function startHeistTimer(duration, bankName) {
    document.getElementById('heist-timer').style.display = 'block';
    let timerText = document.getElementById('timer-text');
    let remainingTime = duration;
    timerText.innerText = `Heist at ${bankName}: ${formatTime(remainingTime)}`;

    clearInterval(heistTimerInterval);
    heistTimerInterval = setInterval(function() {
        remainingTime--;
        if (remainingTime <= 0) {
            clearInterval(heistTimerInterval);
            document.getElementById('heist-timer').style.display = 'none';
            return;
        }
        timerText.innerText = `Heist at ${bankName}: ${formatTime(remainingTime)}`;
    }, 1000);
}

function formatTime(seconds) {
    let mins = Math.floor(seconds / 60);
    let secs = seconds % 60;
    return `${mins}:${secs < 10 ? '0' : ''}${secs}`;
}
