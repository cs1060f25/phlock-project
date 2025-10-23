// Main application logic
class MusicLinkConverter {
    constructor() {
        this.platformLogos = {
            'spotify': '/Spotify_icon.svg',
            'apple': '/Apple_Music_icon.svg',
            'youtube': '/YouTube_icon.svg',
            'youtubeMusic': '/YouTube_Music_icon.svg',
            'amazon': '/Amazon_Music_icon.svg',
            'tidal': '/Tidal_icon.svg',
            'soundcloud': '/SoundCloud_icon.svg'
        };
        this.leftPlatform = 'spotify';
        this.rightPlatform = 'apple';
        this.direction = 'right'; // 'right' = left→right, 'left' = right→left
        this.initializeEventListeners();
    }

    initializeEventListeners() {
        // Logo dropdown toggles
        document.querySelector('[data-type="source"]').addEventListener('click', (e) => {
            e.stopPropagation();
            this.toggleMenu('left');
        });

        document.querySelector('[data-type="target"]').addEventListener('click', (e) => {
            e.stopPropagation();
            this.toggleMenu('right');
        });

        // Platform option clicks
        document.querySelectorAll('#sourceMenu .platform-option').forEach(option => {
            option.addEventListener('click', (e) => {
                e.stopPropagation();
                this.selectPlatform('left', option.dataset.platform);
                this.closeAllMenus();
            });
        });

        document.querySelectorAll('#targetMenu .platform-option').forEach(option => {
            option.addEventListener('click', (e) => {
                e.stopPropagation();
                this.selectPlatform('right', option.dataset.platform);
                this.closeAllMenus();
            });
        });

        // Close menus when clicking outside
        document.addEventListener('click', () => {
            this.closeAllMenus();
        });

        // Direction toggle button
        const directionToggle = document.getElementById('directionToggle');
        directionToggle.addEventListener('click', (e) => {
            e.stopPropagation();
            this.toggleDirection();
        });

        // Keyboard support for direction toggle
        directionToggle.addEventListener('keypress', (e) => {
            if (e.key === 'Enter' || e.key === ' ') {
                e.preventDefault();
                this.toggleDirection();
            }
        });

        // Convert button
        document.getElementById('convertBtn').addEventListener('click', () => {
            this.convertLink();
        });

        // Input field changes
        const musicUrl = document.getElementById('musicUrl');
        const clearBtn = document.getElementById('clearBtn');
        const inputWrapper = document.querySelector('.input-wrapper');

        const checkOverflow = () => {
            // Check if text is overflowing
            const isOverflowing = musicUrl.scrollWidth > musicUrl.clientWidth;
            const isAtEnd = musicUrl.scrollLeft + musicUrl.clientWidth >= musicUrl.scrollWidth - 1;
            const isFocused = document.activeElement === musicUrl;
            
            // On desktop: hide gradient when at end
            // On mobile or when unfocused: always show gradient if overflowing
            const isMobile = window.innerWidth <= 600;
            
            if (isOverflowing && (!isAtEnd || isMobile || !isFocused)) {
                inputWrapper.classList.add('has-overflow');
            } else {
                inputWrapper.classList.remove('has-overflow');
            }
        };

        musicUrl.addEventListener('input', () => {
            clearBtn.style.display = musicUrl.value ? 'block' : 'none';
            checkOverflow();
        });

        musicUrl.addEventListener('blur', () => {
            checkOverflow();
        });

        musicUrl.addEventListener('focus', () => {
            checkOverflow();
        });

        musicUrl.addEventListener('scroll', () => {
            checkOverflow();
        });

        // Enter key support
        musicUrl.addEventListener('keypress', (e) => {
            if (e.key === 'Enter') {
                this.convertLink();
            }
        });

        // Clear button
        clearBtn.addEventListener('click', () => {
            musicUrl.value = '';
            clearBtn.style.display = 'none';
            inputWrapper.classList.remove('has-overflow');
            musicUrl.focus();
            this.clearResult();
        });

        // Copy button
        document.getElementById('copyBtn').addEventListener('click', () => {
            this.copyToClipboard();
        });
    }

    toggleMenu(side) {
        const menu = document.getElementById(side === 'left' ? 'sourceMenu' : 'targetMenu');
        const otherMenu = document.getElementById(side === 'left' ? 'targetMenu' : 'sourceMenu');
        
        // Close other menu
        otherMenu.classList.remove('active');
        
        // Toggle this menu
        menu.classList.toggle('active');
    }

    closeAllMenus() {
        document.getElementById('sourceMenu').classList.remove('active');
        document.getElementById('targetMenu').classList.remove('active');
    }

    selectPlatform(side, platform) {
        if (side === 'left') {
            this.leftPlatform = platform;
            document.getElementById('sourceLogoImg').src = this.platformLogos[platform];
        } else {
            this.rightPlatform = platform;
            document.getElementById('targetLogoImg').src = this.platformLogos[platform];
        }
        this.clearResult();
    }

    toggleDirection() {
        const rightArrow = document.getElementById('rightArrow');
        const leftArrow = document.getElementById('leftArrow');

        // Toggle direction
        this.direction = this.direction === 'right' ? 'left' : 'right';

        // Toggle arrow styles
        if (this.direction === 'right') {
            // Left → Right
            rightArrow.classList.remove('inactive');
            rightArrow.classList.add('active');
            leftArrow.classList.remove('active');
            leftArrow.classList.add('inactive');
        } else {
            // Right → Left
            leftArrow.classList.remove('inactive');
            leftArrow.classList.add('active');
            rightArrow.classList.remove('active');
            rightArrow.classList.add('inactive');
        }

        this.clearResult();
    }

    async convertLink() {
        const url = document.getElementById('musicUrl').value.trim();
        
        if (!url) {
            this.showError('enter a link, dummy');
            return;
        }

        if (!this.isValidUrl(url)) {
            this.showError('that\'s not a valid link, dummy');
            return;
        }

        // Determine source and target based on arrow direction
        const sourcePlatform = this.direction === 'right' ? this.leftPlatform : this.rightPlatform;
        const targetPlatform = this.direction === 'right' ? this.rightPlatform : this.leftPlatform;

        this.showLoading(true);
        this.clearResult();

        try {
            const result = await this.fetchConvertedLink(url, targetPlatform);
            
            if (result.success) {
                this.showSuccess(result.link, result.platform, result.confidence, result.track);
            } else {
                this.showError(result.error || 'Failed to convert link');
            }
        } catch (error) {
            console.error('Conversion error:', error);
            this.showError('Network error. Please try again.');
        } finally {
            this.showLoading(false);
        }
    }

    async fetchConvertedLink(url, targetPlatform) {
        try {
            const response = await fetch('/api/converter', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    url: url,
                    targetPlatform: targetPlatform
                })
            });

            const result = await response.json();
            return result;
        } catch (error) {
            console.error('API call failed:', error);
            return {
                success: false,
                error: 'Network error. Please try again.'
            };
        }
    }

    isValidUrl(string) {
        try {
            new URL(string);
            return true;
        } catch (_) {
            return false;
        }
    }

    showLoading(show) {
        const loading = document.getElementById('loading');
        const convertBtn = document.getElementById('convertBtn');
        
        loading.style.display = show ? 'block' : 'none';
        convertBtn.disabled = show;
    }

    showSuccess(link, platform, confidence, track) {
        const result = document.getElementById('result');
        const resultText = document.getElementById('resultText');
        const resultLink = document.getElementById('resultLink');
        const copyBtn = document.getElementById('copyBtn');
        
        result.className = 'result success';
        
        let trackInfo = '';
        if (track) {
            trackInfo = `${track.title} - ${track.artist}`;
        }
        
        resultText.textContent = trackInfo;
        resultLink.href = link;
        resultLink.textContent = link;
        copyBtn.style.display = 'block';
        result.style.display = 'block';
        
        // Store the link for copying
        this.currentLink = link;
    }

    showError(message) {
        const result = document.getElementById('result');
        const resultText = document.getElementById('resultText');
        const resultLink = document.getElementById('resultLink');
        const copyBtn = document.getElementById('copyBtn');
        
        result.className = 'result error';
        resultText.textContent = `✗ ${message}`;
        resultLink.href = '#';
        resultLink.textContent = '';
        copyBtn.style.display = 'none';
        result.style.display = 'block';
    }

    async copyToClipboard() {
        const copyIcon = document.getElementById('copyIcon');
        
        try {
            await navigator.clipboard.writeText(this.currentLink);
            // Brief visual feedback - show checkmark
            copyIcon.classList.add('copied');
            setTimeout(() => {
                copyIcon.classList.remove('copied');
            }, 1000);
        } catch (err) {
            console.error('Failed to copy:', err);
        }
    }

    clearResult() {
        const copyBtn = document.getElementById('copyBtn');
        document.getElementById('result').style.display = 'none';
        copyBtn.style.display = 'none';
    }
}

// Initialize the app when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    new MusicLinkConverter();
});
