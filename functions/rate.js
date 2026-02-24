const { app } = require('@azure/functions');

app.http('rate', {
    methods: ['POST'],
    authLevel: 'anonymous',
    handler: async (request, context) => {
        let body;

        try {
            body = await request.json();
        } catch {
            return {
                status: 400,
                jsonBody: { success: false, error: 'Invalid JSON in request body' }
            };
        }

        const { key } = body;

        if (key !== process.env.GATEWAY_SECRET) {
            return {
                status: 401,
                jsonBody: { success: false, error: 'Invalid authentication key' }
            };
        }

        const raw = process.env.PROCESSING_RATE;

        if (raw === undefined || raw === null || raw === '') {
            return {
                status: 500,
                jsonBody: { success: false, error: 'PROCESSING_RATE is not configured' }
            };
        }

        const rate = Number(raw);

        if (!Number.isFinite(rate) || rate < 0) {
            return {
                status: 500,
                jsonBody: { success: false, error: 'PROCESSING_RATE is invalid (must be a number >= 0)' }
            };
        }

        return {
            jsonBody: {
                success: true,
                processing_rate: rate
            }
        };
    }
});