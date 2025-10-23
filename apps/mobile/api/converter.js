// Music Link Converter API
// Vercel serverless function

import MusicConverter from '../src/services/music-converter.js';

export default async function handler(req, res) {
    // Set CORS headers
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

    if (req.method === 'OPTIONS') {
        return res.status(200).end();
    }

    if (req.method !== 'POST') {
        return res.status(405).json({ error: 'Method not allowed' });
    }

    try {
        const { url, targetPlatform } = req.body;

        if (!url || !targetPlatform) {
            return res.status(400).json({ 
                success: false, 
                error: 'URL and target platform are required' 
            });
        }

        // Initialize converter
        const converter = new MusicConverter();

        // Perform conversion
        const result = await converter.convert(url, targetPlatform);

        if (!result.success) {
            return res.status(404).json(result);
        }

        return res.status(200).json({
            success: true,
            link: result.convertedUrl,
            platform: result.targetPlatform,
            confidence: result.confidence,
            track: result.track
        });

    } catch (error) {
        console.error('Conversion error:', error);
        return res.status(500).json({ 
            success: false, 
            error: 'Internal server error' 
        });
    }
}

