const APP_CONFIG = {
    resourceName: 'whiskakii-Mafia',
    fadeInDuration: 450,
    fadeOutDuration: 400,
    closeKeys: ['Escape'],
    maxGangNameLength: 16,
    validGangNameRegex: /^[a-zA-Z0-9_]+$/,
    errorDisplayDuration: 3000
};

const GangCreator = (function() {
    let _isVisible = false;
    
    const $body = $('body');
    const $selectionContainer = $('#selectionContainer');
    const $mafiaPanel = $('#mafiaPanel');
    const $costElement = $('#cost');
    const $currencyElement = $('#currency');
    const $gangNameInput = $('#gangNameInput');
    const $createGangBtn = $('#createGangBtn');
    const $notification = $('#notification');

    function init() {
        registerEventListeners();
        console.log('Gang Creator UI initialized');
    }

    function registerEventListeners() {
        window.addEventListener('message', handleNuiMessage);
        document.addEventListener('keyup', handleKeyPress);
        $createGangBtn.on('click', handleGangCreation);
        $gangNameInput.on('input', validateGangName);
    }

    function handleNuiMessage(event) {
        const { action, data } = event.data;
        
        switch (action) {
            case 'show':
                showUI(data);
                break;
            case 'hide':
                hideUI();
                break;
            case 'showError':
                showNotification(data.message, 'error');
                break;
            case 'showSuccess':
                showNotification(data.message, 'success');
                break;
            default:
                console.warn(`Unknown action received: ${action}`);
        }
    }

    function showUI(data) {
        $costElement.text(data.cost);
        $currencyElement.text(data.currency);
        $body.css('opacity', '0').show().animate({ opacity: 1 }, APP_CONFIG.fadeInDuration);
        $selectionContainer.fadeIn(500);
        $gangNameInput.focus();
        _isVisible = true;
    }

    function hideUI() {
        $body.animate({ opacity: 0 }, APP_CONFIG.fadeOutDuration, function() {
            $(this).hide();
            $selectionContainer.hide();
            $mafiaPanel.hide();
            $gangNameInput.val('');
        });
        _isVisible = false;
    }

    function handleKeyPress(event) {
        if (_isVisible && APP_CONFIG.closeKeys.includes(event.key)) {
            closeUI();
        }
    }

    function closeUI() {
        sendNuiMessage('closeNUI');
    }

    function handleGangCreation() {
        const gangName = $gangNameInput.val().trim();
        
        if (!gangName) {
            showNotification('Please enter a gang name', 'error');
            return;
        }
        
        if (gangName.length > APP_CONFIG.maxGangNameLength) {
            showNotification(`Gang name must be ${APP_CONFIG.maxGangNameLength} characters or less`, 'error');
            return;
        }
        
        if (!APP_CONFIG.validGangNameRegex.test(gangName)) {
            showNotification('Gang name can only contain letters, numbers, and underscores', 'error');
            return;
        }
        
        sendNuiMessage('onPlayerCreation', { value: gangName });
    }
    
    function validateGangName() {
        const gangName = $gangNameInput.val().trim();
        const isValid = !gangName || APP_CONFIG.validGangNameRegex.test(gangName);
        
        if (!isValid) {
            $gangNameInput.addClass('invalid');
        } else {
            $gangNameInput.removeClass('invalid');
        }
    }

    function sendNuiMessage(event, data = {}) {
        try {
            $.post(`https://${APP_CONFIG.resourceName}/${event}`, JSON.stringify(data));
        } catch (error) {
            console.error(`Failed to send NUI message: ${error.message}`);
        }
    }

    function showNotification(message, type = 'error') {
        $notification.text(message)
            .removeClass()
            .addClass(`notification ${type} show`)
            .fadeIn();
        
        setTimeout(() => {
            $notification.removeClass('show');
        }, APP_CONFIG.errorDisplayDuration);
    }

    return {
        init
    };
})();

$(document).ready(function() {
    GangCreator.init();
});

