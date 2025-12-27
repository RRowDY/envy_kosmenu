let isMenuOpen = false;
let menuData = null;
let activeDropdowns = [];
let buttonCooldowns = {}; // Track button cooldowns
const BUTTON_COOLDOWN_MS = 1000; // 1 second cooldown between clicks

// GetParentResourceName is a built-in FiveM function available in NUI context
if (typeof GetParentResourceName === 'undefined') {
    window.GetParentResourceName = function() {
        return window.location.hostname;
    };
}

// Notification System
function showNotification(message, type = 'info', title = '') {
    const container = document.getElementById('notification-container');
    if (!container) return;

    const notification = document.createElement('div');
    notification.className = `notification ${type}`;
    
    const icon = getNotificationIcon(type);
    const displayTitle = title || getNotificationTitle(type);
    
    notification.innerHTML = `
        <div class="notification-icon">${icon}</div>
        <div class="notification-content">
            <div class="notification-title">${displayTitle}</div>
            <div class="notification-message">${message}</div>
        </div>
        <button class="notification-close" onclick="this.parentElement.remove()">×</button>
    `;
    
    container.appendChild(notification);
    
    // Auto remove after 5 seconds
    setTimeout(() => {
        if (notification.parentElement) {
            notification.classList.add('hiding');
            setTimeout(() => notification.remove(), 300);
        }
    }, 5000);
}

function getNotificationIcon(type) {
    const icons = {
        error: '<svg width="24" height="24" viewBox="-2 -2 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M12 8V12M12 16H12.01M21 12C21 16.9706 16.9706 21 12 21C7.02944 21 3 16.9706 3 12C3 7.02944 7.02944 3 12 3C16.9706 3 21 7.02944 21 12Z" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>',
        success: '<svg width="24" height="24" viewBox="-2 -2 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M9 12L11 14L15 10M21 12C21 16.9706 16.9706 21 12 21C7.02944 21 3 16.9706 3 12C3 7.02944 7.02944 3 12 3C16.9706 3 21 7.02944 21 12Z" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>',
        warning: '<svg width="24" height="24" viewBox="-2 -2 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M12 9V13M12 17H12.01M21 12C21 16.9706 16.9706 21 12 21C7.02944 21 3 16.9706 3 12C3 7.02944 7.02944 3 12 3C16.9706 3 21 7.02944 21 12Z" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>',
        info: '<svg width="24" height="24" viewBox="-2 -2 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M12 16V12M12 8H12.01M21 12C21 16.9706 16.9706 21 12 21C7.02944 21 3 16.9706 3 12C3 7.02944 7.02944 3 12 3C16.9706 3 21 7.02944 21 12Z" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>'
    };
    return icons[type] || icons.info;
}

function getNotificationTitle(type) {
    const titles = {
        error: 'Error',
        success: 'Success',
        warning: 'Warning',
        info: 'Info'
    };
    return titles[type] || 'Info';
}

// Custom Dropdown System
// Store dropdown instances to prevent duplicate listeners
const dropdownInstances = {};

function createDropdown(dropdownId, options, selectedValue = '', placeholder = 'Select an option...') {
    const dropdown = document.getElementById(dropdownId);
    if (!dropdown) return null;

    const selected = dropdown.querySelector('.dropdown-selected');
    const optionsContainer = dropdown.querySelector('.dropdown-options');
    const hiddenInput = dropdown.querySelector('input[type="hidden"]');
    
    if (!selected || !optionsContainer || !hiddenInput) return null;

    // Close dropdown if it's open
    closeDropdown(dropdownId);

    // Remove existing click listener if it exists
    if (dropdownInstances[dropdownId] && dropdownInstances[dropdownId].clickHandler) {
        selected.removeEventListener('click', dropdownInstances[dropdownId].clickHandler);
    }

    // Clear existing options
    optionsContainer.innerHTML = '';
    
    // Set placeholder if no value selected
    const textSpan = selected.querySelector('.dropdown-text');
    if (textSpan) {
        if (selectedValue && options.find(opt => opt.value === selectedValue)) {
            const selectedOption = options.find(opt => opt.value === selectedValue);
            // Only show main text, not subtitle in selected display
            textSpan.textContent = selectedOption.text;
            textSpan.classList.remove('placeholder');
            hiddenInput.value = selectedValue;
        } else {
            textSpan.textContent = placeholder;
            textSpan.classList.add('placeholder');
            hiddenInput.value = '';
        }
    }

    // Create options
    options.forEach(option => {
        const optionEl = document.createElement('div');
        optionEl.className = 'dropdown-option';
        if (option.value === selectedValue) {
            optionEl.classList.add('selected');
        }
        
        // Create option content with subtitle if creatorName exists
        const optionContent = document.createElement('div');
        optionContent.className = 'dropdown-option-content';
        
        const optionText = document.createElement('div');
        optionText.className = 'dropdown-option-text';
        optionText.textContent = option.text;
        optionContent.appendChild(optionText);
        
        // Add creator name subtitle if available
        if (option.creatorName) {
            const optionSubtitle = document.createElement('div');
            optionSubtitle.className = 'dropdown-option-subtitle';
            optionSubtitle.textContent = option.creatorName;
            optionContent.appendChild(optionSubtitle);
        }
        
        optionEl.appendChild(optionContent);
        optionEl.dataset.value = option.value;
        
        optionEl.addEventListener('click', function(e) {
            e.stopPropagation();
            // Update selected value (only show main text, not subtitle)
            textSpan.textContent = option.text;
            textSpan.classList.remove('placeholder');
            hiddenInput.value = option.value;
            
            // Update selected state
            optionsContainer.querySelectorAll('.dropdown-option').forEach(opt => {
                opt.classList.remove('selected');
            });
            optionEl.classList.add('selected');
            
            // Close dropdown
            closeDropdown(dropdownId);
        });
        
        optionsContainer.appendChild(optionEl);
    });

    // Create new click handler
    const clickHandler = function(e) {
        e.stopPropagation();
        toggleDropdown(dropdownId);
    };
    
    // Add click listener
    selected.addEventListener('click', clickHandler);
    
    // Store the handler for later removal
    dropdownInstances[dropdownId] = {
        clickHandler: clickHandler,
        getValue: () => hiddenInput.value,
        setValue: (value) => {
            const option = options.find(opt => opt.value === value);
            if (option) {
                textSpan.textContent = option.text;
                textSpan.classList.remove('placeholder');
                hiddenInput.value = value;
                optionsContainer.querySelectorAll('.dropdown-option').forEach(opt => {
                    opt.classList.remove('selected');
                    if (opt.dataset.value === value) {
                        opt.classList.add('selected');
                    }
                });
            }
        }
    };

    return dropdownInstances[dropdownId];
}

// Create searchable dropdown (for player selection)
function createSearchableDropdown(dropdownId, options, selectedValue, placeholder) {
    const dropdown = document.getElementById(dropdownId);
    if (!dropdown) return null;
    
    // Clear existing dropdown
    const existing = dropdownInstances[dropdownId];
    if (existing && existing.clickHandler) {
        const selected = dropdown.querySelector('.dropdown-selected');
        if (selected) {
            selected.removeEventListener('click', existing.clickHandler);
        }
    }
    
    const selected = dropdown.querySelector('.dropdown-selected');
    const optionsContainer = dropdown.querySelector('.dropdown-options');
    const hiddenInput = dropdown.querySelector('input[type="hidden"]');
    const searchInput = dropdown.querySelector('.dropdown-search-input');
    
    if (!selected || !optionsContainer || !hiddenInput || !searchInput) return null;
    
    // Store original options for filtering
    const originalOptions = options;
    let filteredOptions = options;
    
    // Clear options container and reset search input
    optionsContainer.innerHTML = '';
    searchInput.value = '';
    
    // Set placeholder
    if (!selectedValue) {
        searchInput.placeholder = placeholder || 'Type to search...';
        hiddenInput.value = '';
    } else {
        const selectedOption = originalOptions.find(opt => opt.value === selectedValue);
        if (selectedOption) {
            searchInput.value = selectedOption.text;
            hiddenInput.value = selectedValue;
        }
    }
    
    // Function to render options
    function renderOptions(optionsToRender) {
        optionsContainer.innerHTML = '';
        
        if (optionsToRender.length === 0) {
            const noResults = document.createElement('div');
            noResults.className = 'dropdown-option no-results';
            noResults.textContent = 'No players found';
            optionsContainer.appendChild(noResults);
            return;
        }
        
        optionsToRender.forEach(option => {
            const optionEl = document.createElement('div');
            optionEl.className = 'dropdown-option';
            if (option.value === selectedValue) {
                optionEl.classList.add('selected');
            }
            optionEl.textContent = option.text;
            optionEl.dataset.value = option.value;
            
            optionEl.addEventListener('click', function(e) {
                e.stopPropagation();
                // Update selected value
                searchInput.value = option.text;
                hiddenInput.value = option.value;
                
                // Update selected state
                optionsContainer.querySelectorAll('.dropdown-option').forEach(opt => {
                    opt.classList.remove('selected');
                });
                optionEl.classList.add('selected');
                
                // Close dropdown
                closeDropdown(dropdownId);
            });
            
            optionsContainer.appendChild(optionEl);
        });
    }
    
    // Initial render
    renderOptions(filteredOptions);
    
    // Search input handler
    searchInput.addEventListener('input', function(e) {
        e.stopPropagation();
        const searchText = this.value.toLowerCase().trim();
        
        if (searchText === '') {
            filteredOptions = originalOptions;
        } else {
            filteredOptions = originalOptions.filter(option => {
                return option.searchText && option.searchText.includes(searchText);
            });
        }
        
        renderOptions(filteredOptions);
        
        // Open dropdown if not already open
        if (!selected.classList.contains('active')) {
            toggleDropdown(dropdownId);
        }
    });
    
    // Click handler for dropdown toggle
    const clickHandler = function(e) {
        // Don't toggle if clicking on the search input
        if (e.target === searchInput) {
            e.stopPropagation();
            if (!selected.classList.contains('active')) {
                toggleDropdown(dropdownId);
            }
            searchInput.focus();
            return;
        }
        e.stopPropagation();
        toggleDropdown(dropdownId);
    };
    
    // Add click listener to selected (but not on search input)
    selected.addEventListener('click', clickHandler);
    
    // Focus search input when dropdown opens
    const originalToggle = toggleDropdown;
    const observer = new MutationObserver(function(mutations) {
        mutations.forEach(function(mutation) {
            if (mutation.attributeName === 'class' && selected.classList.contains('active')) {
                setTimeout(() => {
                    searchInput.focus();
                    if (searchInput.value === '') {
                        searchInput.select();
                    }
                }, 10);
            }
        });
    });
    observer.observe(selected, { attributes: true });
    
    // Store the handler and options
    dropdownInstances[dropdownId] = {
        clickHandler: clickHandler,
        originalOptions: originalOptions,
        getValue: () => hiddenInput.value,
        setValue: (value) => {
            const option = originalOptions.find(opt => opt.value === value);
            if (option) {
                searchInput.value = option.text;
                hiddenInput.value = value;
                renderOptions(originalOptions);
                optionsContainer.querySelectorAll('.dropdown-option').forEach(opt => {
                    opt.classList.remove('selected');
                    if (opt.dataset.value === value) {
                        opt.classList.add('selected');
                    }
                });
            }
        }
    };
    
    return dropdownInstances[dropdownId];
}

function toggleDropdown(dropdownId) {
    // Close all other dropdowns
    activeDropdowns.forEach(id => {
        if (id !== dropdownId) {
            closeDropdown(id);
        }
    });

    const dropdown = document.getElementById(dropdownId);
    if (!dropdown) return;

    const selected = dropdown.querySelector('.dropdown-selected');
    const options = dropdown.querySelector('.dropdown-options');
    
    if (!selected || !options) return;

    const isActive = selected.classList.contains('active');
    
    if (isActive) {
        closeDropdown(dropdownId);
    } else {
        selected.classList.add('active');
        options.classList.remove('hidden');
        activeDropdowns.push(dropdownId);
    }
}

function closeDropdown(dropdownId) {
    const dropdown = document.getElementById(dropdownId);
    if (!dropdown) return;

    const selected = dropdown.querySelector('.dropdown-selected');
    const options = dropdown.querySelector('.dropdown-options');
    
    if (selected) {
        selected.classList.remove('active');
    }
    if (options) {
        options.classList.add('hidden');
    }
    
    activeDropdowns = activeDropdowns.filter(id => id !== dropdownId);
}

function closeAllDropdowns() {
    activeDropdowns.forEach(id => closeDropdown(id));
}

// Handle action results from server
function handleActionResult(success, actionType, message) {
    const actionMessages = {
        'giveAmmo': success ? (message || 'Ammo given to all players in bucket') : 'Failed to give ammo',
        'repairWeapons': success ? (message || 'Weapons repaired for all players in bucket') : 'Failed to repair weapons',
        'revivePlayers': success ? (message || 'All players in bucket have been revived') : 'Failed to revive players',
        'createBucket': success ? (message || 'Bucket created successfully') : 'Failed to create bucket',
        'deleteBucket': success ? (message || 'Bucket deleted successfully') : 'Failed to delete bucket',
        'teleportToBucket': success ? (message || 'Player teleported successfully') : 'Failed to teleport player',
        'leaveBucket': success ? (message || 'Left bucket successfully') : 'Failed to leave bucket'
    };
    
    const notificationType = success ? 'success' : 'error';
    const notificationMessage = actionMessages[actionType] || message || (success ? 'Action completed successfully' : 'Action failed');
    
    showNotification(notificationMessage, notificationType);
}

// Spectate overlay functions
function showSpectateOverlay(playerName) {
    const overlay = document.getElementById('spectate-overlay');
    const nameElement = document.getElementById('spectate-player-name');
    
    if (overlay && nameElement) {
        nameElement.textContent = `Spectating: ${playerName}`;
        overlay.classList.remove('hidden');
        // Force display and opacity to ensure visibility
        overlay.style.display = 'flex';
        overlay.style.opacity = '1';
        overlay.style.visibility = 'visible';
        overlay.style.zIndex = '10000';
    }
}

function hideSpectateOverlay() {
    const overlay = document.getElementById('spectate-overlay');
    if (overlay) {
        overlay.classList.add('hidden');
        setTimeout(() => {
            overlay.style.display = 'none';
        }, 300);
    }
}

// Scoreboard functions
let currentScoreboardData = null;

function updateScoreboard(data) {
    const overlay = document.getElementById('scoreboard-overlay');
    if (!overlay) return;
    
    if (!data || !data.visible) {
        overlay.classList.add('hidden');
        overlay.style.display = 'none';
        overlay.style.opacity = '0';
        overlay.style.visibility = 'hidden';
        currentScoreboardData = null;
        return;
    }
    
    // Store current scoreboard data for use in modals
    currentScoreboardData = data;
    
    // Update team names and scores
    const team1Name = document.getElementById('scoreboard-team1-name');
    const team1Score = document.getElementById('scoreboard-team1-score');
    const team2Name = document.getElementById('scoreboard-team2-name');
    const team2Score = document.getElementById('scoreboard-team2-score');
    
    if (team1Name) team1Name.textContent = data.team1Name || 'Team 1';
    if (team1Score) {
        const oldScore = parseInt(team1Score.textContent) || 0;
        const newScore = data.team1Score || 0;
        team1Score.textContent = newScore;
        // Add pulse animation when score changes
        if (oldScore !== newScore) {
            team1Score.classList.add('changed');
            setTimeout(() => team1Score.classList.remove('changed'), 500);
        }
    }
    if (team2Name) team2Name.textContent = data.team2Name || 'Team 2';
    if (team2Score) {
        const oldScore = parseInt(team2Score.textContent) || 0;
        const newScore = data.team2Score || 0;
        team2Score.textContent = newScore;
        // Add pulse animation when score changes
        if (oldScore !== newScore) {
            team2Score.classList.add('changed');
            setTimeout(() => team2Score.classList.remove('changed'), 500);
        }
    }
    
    // Show overlay using same pattern as spectate overlay
    overlay.classList.remove('hidden');
    overlay.style.display = 'flex';
    overlay.style.opacity = '1';
    overlay.style.visibility = 'visible';
}

function showScoreChangeNotification(teamName, oldScore, newScore) {
    // Remove existing notification if any
    const existing = document.querySelector('.score-change-notification');
    if (existing) {
        existing.remove();
    }
    
    // Create notification element
    const notification = document.createElement('div');
    notification.className = 'score-change-notification';
    notification.innerHTML = `
        <span class="team-name">${teamName}</span>
        <span class="score-change">${oldScore} → ${newScore}</span>
    `;
    
    document.body.appendChild(notification);
    
    // Remove after animation
    setTimeout(() => {
        notification.remove();
    }, 3000);
}

// Generic button click handler with cooldown and feedback
function handleButtonClick(buttonId, actionName, buttonElement, data = {}) {
    // Check cooldown
    const now = Date.now();
    if (buttonCooldowns[buttonId] && (now - buttonCooldowns[buttonId]) < BUTTON_COOLDOWN_MS) {
        const remaining = Math.ceil((BUTTON_COOLDOWN_MS - (now - buttonCooldowns[buttonId])) / 1000);
        showNotification(`Please wait ${remaining} second${remaining > 1 ? 's' : ''} before clicking again`, 'warning');
        return;
    }
    
    // Set cooldown
    buttonCooldowns[buttonId] = now;
    
    // Add loading state
    buttonElement.classList.add('loading');
    buttonElement.disabled = true;
    
    // Remove loading state after a delay
    setTimeout(() => {
        buttonElement.classList.remove('loading');
        buttonElement.disabled = false;
    }, 500);
    
    // Send request
    fetch(`https://${GetParentResourceName()}/${actionName}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data)
    });
}

// Listen for messages from Lua
window.addEventListener('message', function(event) {
    const data = event.data;
    
    switch(data.action) {
        case 'openMenu':
            openMenu(data.data);
            break;
        case 'closeMenu':
            closeMenu();
            break;
        case 'updateMenu':
            updateMenu(data.data);
            break;
        case 'actionResult':
            handleActionResult(data.success, data.actionType, data.message);
            break;
        case 'showSpectate':
            showSpectateOverlay(data.playerName);
            break;
        case 'hideSpectate':
            hideSpectateOverlay();
            break;
        case 'updateScoreboard':
            updateScoreboard(data.data);
            break;
        case 'scoreChange':
            showScoreChangeNotification(data.teamName, data.oldScore, data.newScore);
            break;
    }
});

// Open menu function
function openMenu(data) {
    if (isMenuOpen) return;
    
    menuData = data;
    
    // Set logo image from config
    if (data.logoImage) {
        const logoIcon = document.querySelector('.logo-icon');
        if (logoIcon) {
            logoIcon.style.backgroundImage = `url('${data.logoImage}')`;
        }
    }
    const container = document.getElementById('kos-menu-container');
    container.classList.remove('hidden');
    
    setTimeout(() => {
        container.style.display = 'flex';
        renderMenu();
    }, 10);
    
    isMenuOpen = true;
}

// Update menu function
function updateMenu(data) {
    menuData = data;
    renderMenu();
}

// Close menu function
function closeMenu() {
    if (!isMenuOpen) return;
    
    const container = document.getElementById('kos-menu-container');
    container.classList.add('hidden');
    
    setTimeout(() => {
        container.style.display = 'none';
        closeAllModals();
        closeAllDropdowns();
    }, 300);
    
    isMenuOpen = false;
    menuData = null;
}

// Render menu based on data
function renderMenu() {
    if (!menuData) return;
    
    // Update leave bucket button
    const leaveBtn = document.getElementById('leave-bucket-btn');
    if (leaveBtn) {
        if (menuData.canLeaveBucket) {
            leaveBtn.classList.remove('disabled');
        } else {
            leaveBtn.classList.add('disabled');
        }
    }
    
    // Show/hide admin section
    const adminSection = document.getElementById('admin-section');
    if (adminSection) {
        if (menuData.hasPermission) {
            adminSection.classList.remove('hidden');
        } else {
            adminSection.classList.add('hidden');
        }
    }
    
    // Show/hide bucket actions section
    const bucketActionsSection = document.getElementById('bucket-actions-section');
    if (bucketActionsSection) {
        if (menuData.canUseBucketActions) {
            bucketActionsSection.classList.remove('hidden');
        } else {
            bucketActionsSection.classList.add('hidden');
        }
    }
    
    // Show/hide kill log section (available to all users in a bucket)
    const killLogSection = document.getElementById('kill-log-section');
    if (killLogSection) {
        if (menuData.inBucket) {
            killLogSection.classList.remove('hidden');
        } else {
            killLogSection.classList.add('hidden');
        }
    }
    
    // Update admin buttons disabled state
    if (menuData.hasPermission) {
        const createBtn = document.getElementById('create-bucket-btn');
        const deleteBtn = document.getElementById('delete-bucket-btn');
        const teleportBtn = document.getElementById('teleport-bucket-btn');
        
        if (createBtn) createBtn.classList.remove('disabled');
        if (deleteBtn) {
            if (menuData.buckets && menuData.buckets.length > 0) {
                deleteBtn.classList.remove('disabled');
            } else {
                deleteBtn.classList.add('disabled');
            }
        }
        if (teleportBtn) {
            // Only disabled if there are no buckets other than default (bucket 0)
            // Bucket 0 is always available, so we need at least one other bucket OR players available
            const hasBuckets = menuData.buckets && menuData.buckets.length > 0;
            const hasPlayers = menuData.players && menuData.players.length > 0;
            
            // Enable if there are buckets (other than 0) OR if there are players (can teleport to bucket 0)
            if (hasBuckets || hasPlayers) {
                teleportBtn.classList.remove('disabled');
            } else {
                teleportBtn.classList.add('disabled');
            }
        }
        
        const spectateBtn = document.getElementById('spectate-player-btn');
        if (spectateBtn) {
            // Only enabled if in a bucket (not 0) and has players in bucket to spectate
            const inBucket = menuData.inBucket;
            const hasBucketPlayers = menuData.bucketPlayers && menuData.bucketPlayers.length > 0;
            
            if (inBucket && hasBucketPlayers) {
                spectateBtn.classList.remove('disabled');
            } else {
                spectateBtn.classList.add('disabled');
            }
        }
        
        // Edit Scoreboard button - only enabled if in a bucket (not 0)
        const editScoreboardBtn = document.getElementById('edit-scoreboard-btn');
        if (editScoreboardBtn) {
            if (menuData.inBucket) {
                editScoreboardBtn.classList.remove('disabled');
            } else {
                editScoreboardBtn.classList.add('disabled');
            }
        }
        
        // Adjust Score button - only enabled if in a bucket (not 0)
        const adjustScoreBtn = document.getElementById('adjust-score-btn');
        if (adjustScoreBtn) {
            if (menuData.inBucket) {
                adjustScoreBtn.classList.remove('disabled');
            } else {
                adjustScoreBtn.classList.add('disabled');
            }
        }
        
        // View Kill Log button - only enabled if in a bucket (not 0)
        const viewKillLogBtn = document.getElementById('view-kill-log-btn');
        if (viewKillLogBtn) {
            if (menuData.inBucket) {
                viewKillLogBtn.classList.remove('disabled');
            } else {
                viewKillLogBtn.classList.add('disabled');
            }
        }
    }
}

// Modal management
function openModal(modalId) {
    const modal = document.getElementById(modalId);
    if (modal) {
        // Close all dropdowns before opening modal
        closeAllDropdowns();
        modal.classList.remove('hidden');
    }
}

function closeModal(modalId) {
    const modal = document.getElementById(modalId);
    if (modal) {
        modal.classList.add('hidden');
    }
    closeAllDropdowns();
}

function closeAllModals() {
    closeModal('create-bucket-modal');
    closeModal('delete-bucket-modal');
    closeModal('teleport-bucket-modal');
    closeModal('edit-scoreboard-modal');
    closeModal('adjust-score-modal');
    closeModal('kill-log-modal');
}

// Initialize on DOM load
// Initialize scoreboard overlay on page load
function initializeScoreboard() {
    const overlay = document.getElementById('scoreboard-overlay');
    if (overlay) {
        overlay.classList.add('hidden');
        overlay.style.display = 'none';
        overlay.style.opacity = '0';
        overlay.style.visibility = 'hidden';
    }
}

// Kill Log functions
let currentKillLogPage = 1;
let killLogTotalPages = 1;

function openKillLogModal() {
    currentKillLogPage = 1;
    openModal('kill-log-modal');
    loadKillLog(1);
}

// Helper function to format relative time
function formatRelativeTime(timestamp) {
    const now = Math.floor(Date.now() / 1000);
    const diff = now - timestamp;
    
    if (diff < 60) {
        return `${diff}s ago`;
    } else if (diff < 3600) {
        const minutes = Math.floor(diff / 60);
        return `${minutes}m ago`;
    } else if (diff < 7200) {
        return `1h ago`;
    } else {
        return `a long time ago`;
    }
}

function loadKillLog(page) {
    const container = document.getElementById('kill-log-container');
    const pageInfo = document.getElementById('kill-log-page-info');
    const prevBtn = document.getElementById('kill-log-prev');
    const nextBtn = document.getElementById('kill-log-next');
    
    if (container) {
        container.innerHTML = '<div class="kill-log-loading">Loading kill log...</div>';
    }
    
    fetch(`https://${GetParentResourceName()}/getKillLog`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ page: page })
    })
    .then(response => response.json())
    .then(data => {
        currentKillLogPage = data.currentPage || 1;
        killLogTotalPages = data.totalPages || 1;
        
        if (container) {
            if (data.logs && data.logs.length > 0) {
                container.innerHTML = '';
                data.logs.forEach(log => {
                    const entry = document.createElement('div');
                    entry.className = 'kill-log-entry';
                    
                    const timestamp = new Date(log.timestamp * 1000).toLocaleTimeString();
                    const relativeTime = formatRelativeTime(log.timestamp);
                    
                    entry.innerHTML = `
                        <div class="kill-log-entry-header">
                            <span>${timestamp} (${relativeTime})</span>
                        </div>
                        <div class="kill-log-entry-content">
                            <span class="kill-log-killer">${log.killerName}</span>
                            <span class="kill-log-arrow">→</span>
                            <span class="kill-log-killed">${log.killedName}</span>
                            <span class="kill-log-weapon">${log.weapon}</span>
                        </div>
                    `;
                    container.appendChild(entry);
                });
            } else {
                container.innerHTML = '<div class="kill-log-empty">No kills recorded yet</div>';
            }
        }
        
        // Update pagination
        if (pageInfo) {
            pageInfo.textContent = `Page ${currentKillLogPage} of ${killLogTotalPages}`;
        }
        
        if (prevBtn) {
            prevBtn.disabled = currentKillLogPage <= 1;
        }
        
        if (nextBtn) {
            nextBtn.disabled = currentKillLogPage >= killLogTotalPages;
        }
    })
    .catch(error => {
        console.error('Error loading kill log:', error);
        if (container) {
            container.innerHTML = '<div class="kill-log-empty">Error loading kill log</div>';
        }
    });
}

document.addEventListener('DOMContentLoaded', function() {
    initializeScoreboard();
    // Close button
    const closeBtn = document.getElementById('close-btn');
    if (closeBtn) {
        closeBtn.addEventListener('click', function() {
            closeMenu();
            fetch(`https://${GetParentResourceName()}/closeMenu`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({})
            });
        });
    }
    
    // Leave bucket button
    const leaveBtn = document.getElementById('leave-bucket-btn');
    if (leaveBtn) {
        leaveBtn.addEventListener('click', function() {
            if (this.classList.contains('disabled')) return;
            handleButtonClick('leave-bucket-btn', 'leaveBucket', this);
        });
    }
    
    // Create bucket button
    const createBtn = document.getElementById('create-bucket-btn');
    if (createBtn) {
        createBtn.addEventListener('click', function() {
            if (this.classList.contains('disabled')) return;
            openModal('create-bucket-modal');
        });
    }
    
    // Delete bucket button
    const deleteBtn = document.getElementById('delete-bucket-btn');
    if (deleteBtn) {
        deleteBtn.addEventListener('click', function() {
            if (this.classList.contains('disabled')) return;
            
            // Open modal first
            openModal('delete-bucket-modal');
            
            // Populate bucket dropdown after modal is visible
            setTimeout(() => {
                if (menuData && menuData.buckets) {
                    const options = menuData.buckets.map(bucket => ({
                        value: bucket.id.toString(),
                        text: `Bucket ${bucket.id}`,
                        creatorName: bucket.creatorName
                    }));
                    createDropdown('delete-bucket-dropdown', options, '', 'Select a bucket...');
                }
            }, 10);
        });
    }
    
    // Teleport to bucket button
    const teleportBtn = document.getElementById('teleport-bucket-btn');
    if (teleportBtn) {
        teleportBtn.addEventListener('click', function() {
            if (this.classList.contains('disabled')) return;
            
            // Open modal first
            openModal('teleport-bucket-modal');
            
            // Populate dropdowns after modal is visible
            setTimeout(() => {
                // Populate player dropdown (searchable)
                if (menuData && menuData.players) {
                    const playerOptions = menuData.players.map(player => ({
                        value: player.id.toString(),
                        text: `${player.name} (ID: ${player.serverId})`,
                        searchText: `${player.name} ${player.serverId}`.toLowerCase()
                    }));
                    createSearchableDropdown('teleport-player-dropdown', playerOptions, '', 'Type to search...');
                }
                
                // Populate bucket dropdown (include bucket 0)
                const bucketOptions = [{ value: '0', text: 'Main Dimension (0)' }];
                if (menuData && menuData.buckets) {
                    menuData.buckets.forEach(bucket => {
                        bucketOptions.push({
                            value: bucket.id.toString(),
                            text: `Bucket ${bucket.id}`,
                            creatorName: bucket.creatorName
                        });
                    });
                }
                createDropdown('teleport-bucket-dropdown', bucketOptions, '0', 'Select a bucket...');
            }, 10);
        });
    }
    
    // Give ammo button
    const giveAmmoBtn = document.getElementById('give-ammo-btn');
    if (giveAmmoBtn) {
        giveAmmoBtn.addEventListener('click', function() {
            if (this.classList.contains('disabled')) return;
            handleButtonClick('give-ammo-btn', 'giveAmmo', this);
        });
    }
    
    // Repair weapons button
    const repairWeaponsBtn = document.getElementById('repair-weapons-btn');
    if (repairWeaponsBtn) {
        repairWeaponsBtn.addEventListener('click', function() {
            if (this.classList.contains('disabled')) return;
            handleButtonClick('repair-weapons-btn', 'repairWeapons', this);
        });
    }
    
    // Revive players button
    const revivePlayersBtn = document.getElementById('revive-players-btn');
    if (revivePlayersBtn) {
        revivePlayersBtn.addEventListener('click', function() {
            if (this.classList.contains('disabled')) return;
            handleButtonClick('revive-players-btn', 'revivePlayers', this);
        });
    }
    
    // Spectate player button
    const spectatePlayerBtn = document.getElementById('spectate-player-btn');
    if (spectatePlayerBtn) {
        spectatePlayerBtn.addEventListener('click', function() {
            if (this.classList.contains('disabled')) return;
            handleButtonClick('spectate-player-btn', 'spectatePlayer', this);
        });
    }
    
    // Move bucket button
    const moveBucketBtn = document.getElementById('move-bucket-btn');
    if (moveBucketBtn) {
        moveBucketBtn.addEventListener('click', function() {
            if (this.classList.contains('disabled')) return;
            handleButtonClick('move-bucket-btn', 'moveBucket', this);
        });
    }
    
    // Edit scoreboard button
    const editScoreboardBtn = document.getElementById('edit-scoreboard-btn');
    if (editScoreboardBtn) {
        editScoreboardBtn.addEventListener('click', function() {
            if (this.classList.contains('disabled')) return;
            openModal('edit-scoreboard-modal');
            
            // Fetch fresh scoreboard data
            fetch(`https://${GetParentResourceName()}/getScoreboard`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({})
            })
            .then(response => {
                if (!response.ok) {
                    throw new Error('Network response was not ok');
                }
                return response.json();
            })
            .then(data => {
                // Update current scoreboard data
                if (data) {
                    currentScoreboardData = data;
                }
                
                // Populate fields with current scoreboard data
                const team1Input = document.getElementById('team1-name');
                const team2Input = document.getElementById('team2-name');
                const visibleCheckbox = document.getElementById('scoreboard-visible');
                
                if (team1Input) team1Input.value = data?.team1Name || 'Team 1';
                if (team2Input) team2Input.value = data?.team2Name || 'Team 2';
                if (visibleCheckbox) visibleCheckbox.checked = data?.visible || false;
            })
            .catch(error => {
                console.error('Error fetching scoreboard:', error);
                // Fallback to current data or defaults
                if (currentScoreboardData) {
                    const team1Input = document.getElementById('team1-name');
                    const team2Input = document.getElementById('team2-name');
                    const visibleCheckbox = document.getElementById('scoreboard-visible');
                    
                    if (team1Input) team1Input.value = currentScoreboardData.team1Name || 'Team 1';
                    if (team2Input) team2Input.value = currentScoreboardData.team2Name || 'Team 2';
                    if (visibleCheckbox) visibleCheckbox.checked = currentScoreboardData.visible || false;
                }
            });
        });
    }
    
    // Adjust score button
    const adjustScoreBtn = document.getElementById('adjust-score-btn');
    if (adjustScoreBtn) {
        adjustScoreBtn.addEventListener('click', function() {
            if (this.classList.contains('disabled')) return;
            openModal('adjust-score-modal');
            
            // Fetch fresh scoreboard data to get current team names
            fetch(`https://${GetParentResourceName()}/getScoreboard`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({})
            })
            .then(response => {
                if (!response.ok) {
                    throw new Error('Network response was not ok');
                }
                return response.json();
            })
            .then(data => {
                console.log('Scoreboard data received:', data); // Debug log
                // Update current scoreboard data
                if (data) {
                    currentScoreboardData = data;
                }
                
                // Populate team dropdown with actual team names
                const team1Name = data?.team1Name || 'Team 1';
                const team2Name = data?.team2Name || 'Team 2';
                
                console.log('Team names:', team1Name, team2Name); // Debug log
                
                const teamOptions = [
                    { value: '1', text: team1Name },
                    { value: '2', text: team2Name }
                ];
                createDropdown('adjust-team-dropdown', teamOptions, '', 'Select a team...');
            })
            .catch(error => {
                console.error('Error fetching scoreboard:', error);
                // Fallback to current data or defaults
                const team1Name = currentScoreboardData?.team1Name || 'Team 1';
                const team2Name = currentScoreboardData?.team2Name || 'Team 2';
                
                const teamOptions = [
                    { value: '1', text: team1Name },
                    { value: '2', text: team2Name }
                ];
                createDropdown('adjust-team-dropdown', teamOptions, '', 'Select a team...');
            });
        });
    }
    
    // Create bucket modal handlers
    const createModal = document.getElementById('create-bucket-modal');
    const createClose = document.getElementById('create-bucket-close');
    const createCancel = document.getElementById('create-bucket-cancel');
    const createConfirm = document.getElementById('create-bucket-confirm');
    
    if (createClose) {
        createClose.addEventListener('click', () => closeModal('create-bucket-modal'));
    }
    if (createCancel) {
        createCancel.addEventListener('click', () => closeModal('create-bucket-modal'));
    }
    if (createConfirm) {
        createConfirm.addEventListener('click', function() {
            const bucketId = document.getElementById('create-bucket-id').value;
            if (!bucketId || bucketId <= 0) {
                showNotification('Please enter a valid bucket ID (greater than 0)', 'error');
                return;
            }
            
            // Add loading state to button
            this.classList.add('loading');
            this.disabled = true;
            
            fetch(`https://${GetParentResourceName()}/createBucket`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ bucketId: parseInt(bucketId) })
            }).finally(() => {
                // Remove loading state
                this.classList.remove('loading');
                this.disabled = false;
            });
            
            document.getElementById('create-bucket-id').value = '';
            closeModal('create-bucket-modal');
        });
    }
    
    // Delete bucket modal handlers
    const deleteModal = document.getElementById('delete-bucket-modal');
    const deleteClose = document.getElementById('delete-bucket-close');
    const deleteCancel = document.getElementById('delete-bucket-cancel');
    const deleteConfirm = document.getElementById('delete-bucket-confirm');
    
    if (deleteClose) {
        deleteClose.addEventListener('click', () => closeModal('delete-bucket-modal'));
    }
    if (deleteCancel) {
        deleteCancel.addEventListener('click', () => closeModal('delete-bucket-modal'));
    }
    if (deleteConfirm) {
        deleteConfirm.addEventListener('click', function() {
            const bucketId = document.getElementById('delete-bucket-id').value;
            if (!bucketId) {
                showNotification('Please select a bucket to delete', 'error');
                return;
            }
            
            const bucketNum = parseInt(bucketId);
            
            // Add loading state to button
            this.classList.add('loading');
            this.disabled = true;
            
            fetch(`https://${GetParentResourceName()}/deleteBucket`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ bucketId: bucketNum })
            }).finally(() => {
                // Remove loading state
                this.classList.remove('loading');
                this.disabled = false;
            });
            
            closeModal('delete-bucket-modal');
        });
    }
    
    // Teleport bucket modal handlers
    const teleportModal = document.getElementById('teleport-bucket-modal');
    const teleportClose = document.getElementById('teleport-bucket-close');
    const teleportCancel = document.getElementById('teleport-bucket-cancel');
    const teleportConfirm = document.getElementById('teleport-bucket-confirm');
    
    if (teleportClose) {
        teleportClose.addEventListener('click', () => closeModal('teleport-bucket-modal'));
    }
    if (teleportCancel) {
        teleportCancel.addEventListener('click', () => closeModal('teleport-bucket-modal'));
    }
    if (teleportConfirm) {
        teleportConfirm.addEventListener('click', function() {
            const playerId = document.getElementById('teleport-player-id').value;
            const bucketId = document.getElementById('teleport-bucket-id').value;
            
            if (!playerId) {
                showNotification('Please select a player', 'error');
                return;
            }
            
            if (!bucketId && bucketId !== '0') {
                showNotification('Please select a bucket', 'error');
                return;
            }
            
            // Add loading state to button
            this.classList.add('loading');
            this.disabled = true;
            
            fetch(`https://${GetParentResourceName()}/teleportToBucket`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ 
                    targetPlayerId: parseInt(playerId),
                    bucketId: parseInt(bucketId)
                })
            }).finally(() => {
                // Remove loading state
                this.classList.remove('loading');
                this.disabled = false;
            });
            
            closeModal('teleport-bucket-modal');
        });
    }
    
    // Edit scoreboard modal handlers
    const editScoreboardModal = document.getElementById('edit-scoreboard-modal');
    const editScoreboardClose = document.getElementById('edit-scoreboard-close');
    const editScoreboardCancel = document.getElementById('edit-scoreboard-cancel');
    const editScoreboardConfirm = document.getElementById('edit-scoreboard-confirm');
    
    if (editScoreboardClose) {
        editScoreboardClose.addEventListener('click', () => closeModal('edit-scoreboard-modal'));
    }
    if (editScoreboardCancel) {
        editScoreboardCancel.addEventListener('click', () => closeModal('edit-scoreboard-modal'));
    }
    if (editScoreboardConfirm) {
        editScoreboardConfirm.addEventListener('click', function() {
            const team1Name = document.getElementById('team1-name').value.trim() || 'Team 1';
            const team2Name = document.getElementById('team2-name').value.trim() || 'Team 2';
            const visible = document.getElementById('scoreboard-visible').checked;
            
            // Add loading state
            this.classList.add('loading');
            this.disabled = true;
            
            fetch(`https://${GetParentResourceName()}/updateScoreboard`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    team1Name: team1Name,
                    team2Name: team2Name,
                    visible: visible
                })
            }).finally(() => {
                this.classList.remove('loading');
                this.disabled = false;
            });
            
            closeModal('edit-scoreboard-modal');
        });
    }
    
    // View kill log button
    const viewKillLogBtn = document.getElementById('view-kill-log-btn');
    if (viewKillLogBtn) {
        viewKillLogBtn.addEventListener('click', function() {
            if (this.classList.contains('disabled')) return;
            openKillLogModal();
        });
    }
    
    // Kill log modal handlers
    const killLogModal = document.getElementById('kill-log-modal');
    const killLogClose = document.getElementById('kill-log-close');
    const killLogCloseBtn = document.getElementById('kill-log-close-btn');
    const killLogPrev = document.getElementById('kill-log-prev');
    const killLogNext = document.getElementById('kill-log-next');
    
    if (killLogClose) {
        killLogClose.addEventListener('click', () => closeModal('kill-log-modal'));
    }
    if (killLogCloseBtn) {
        killLogCloseBtn.addEventListener('click', () => closeModal('kill-log-modal'));
    }
    if (killLogPrev) {
        killLogPrev.addEventListener('click', function() {
            if (!this.disabled && currentKillLogPage > 1) {
                loadKillLog(currentKillLogPage - 1);
            }
        });
    }
    if (killLogNext) {
        killLogNext.addEventListener('click', function() {
            if (!this.disabled && currentKillLogPage < killLogTotalPages) {
                loadKillLog(currentKillLogPage + 1);
            }
        });
    }
    
    // Adjust score modal handlers
    const adjustScoreModal = document.getElementById('adjust-score-modal');
    const adjustScoreClose = document.getElementById('adjust-score-close');
    const adjustScoreCancel = document.getElementById('adjust-score-cancel');
    const adjustScoreConfirm = document.getElementById('adjust-score-confirm');
    
    if (adjustScoreClose) {
        adjustScoreClose.addEventListener('click', () => closeModal('adjust-score-modal'));
    }
    if (adjustScoreCancel) {
        adjustScoreCancel.addEventListener('click', () => closeModal('adjust-score-modal'));
    }
    if (adjustScoreConfirm) {
        adjustScoreConfirm.addEventListener('click', function() {
            const teamId = document.getElementById('adjust-team-id').value;
            const score = document.getElementById('adjust-score-value').value;
            
            if (!teamId) {
                showNotification('Please select a team', 'error');
                return;
            }
            
            if (!score || score < 0) {
                showNotification('Please enter a valid score (0 or greater)', 'error');
                return;
            }
            
            // Add loading state
            this.classList.add('loading');
            this.disabled = true;
            
            fetch(`https://${GetParentResourceName()}/adjustScore`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    team: parseInt(teamId),
                    score: parseInt(score)
                })
            }).finally(() => {
                this.classList.remove('loading');
                this.disabled = false;
            });
            
            document.getElementById('adjust-score-value').value = '';
            closeModal('adjust-score-modal');
        });
    }
    
    // Close modals when clicking outside
    document.querySelectorAll('.modal').forEach(modal => {
        modal.addEventListener('click', function(e) {
            if (e.target === this) {
                closeModal(this.id);
            }
        });
    });
    
    // Close dropdowns when clicking outside
    document.addEventListener('click', function(e) {
        // Don't close if clicking on a dropdown element
        if (e.target.closest('.custom-dropdown')) {
            return;
        }
        // Close all dropdowns if clicking outside
        closeAllDropdowns();
    });
    
    // ESC key handler
    document.addEventListener('keydown', function(event) {
        if (event.key === 'Escape') {
            if (isMenuOpen) {
                // Close any open dropdowns first
                if (activeDropdowns.length > 0) {
                    closeAllDropdowns();
                }
                // Close any open modals
                else if (!document.getElementById('create-bucket-modal').classList.contains('hidden')) {
                    closeModal('create-bucket-modal');
                } else if (!document.getElementById('delete-bucket-modal').classList.contains('hidden')) {
                    closeModal('delete-bucket-modal');
                } else if (!document.getElementById('teleport-bucket-modal').classList.contains('hidden')) {
                    closeModal('teleport-bucket-modal');
                } else {
                    // Close menu if no modals/dropdowns open
                    closeMenu();
                    fetch(`https://${GetParentResourceName()}/closeMenu`, {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({})
                    });
                }
            }
        }
    });
});
