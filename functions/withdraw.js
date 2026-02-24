const { app } = require('@azure/functions');
const sql = require('mssql');

app.http('withdraw', {
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

        const { card_id, amount, key } = body;

        if (key !== process.env.GATEWAY_SECRET) {
            return {
                status: 401,
                jsonBody: { success: false, error: 'Invalid authentication key' }
            };
        }

        if (!card_id) {
            return { 
                status: 400, 
                jsonBody: { success: false, error: 'The card_id field is required' } 
            };
        }
        
        const numericAmount = Number(amount);
        if (!Number.isInteger(numericAmount) || numericAmount <= 0) {
            return {
                status: 400,
                jsonBody: { success: false, error: 'Amount must be a positive whole number' }
            };
        }

        try {
            await sql.connect(process.env.SQL_CONNECTION_STRING);

            const result = await sql.query`
                UPDATE user_accounts
                SET balance = balance - ${numericAmount}, last_used = SYSUTCDATETIME()
                OUTPUT 
                    inserted.owner,
                    inserted.balance,
                    inserted.last_used
                WHERE card_id = ${card_id} AND balance >= ${numericAmount}
            `;

            if (result.recordset.length === 0) {
                return {
                    jsonBody: { 
                        success: false, 
                        error: 'Insufficient funds or invalid card ID'
                    }
                };
            }

            const account = result.recordset[0];

            return {
                jsonBody: {
                    success: true,
                    owner: account.owner,
                    balance: account.balance,
                    last_used: account.last_used
                }
            };

        } catch (err) {
            context.log(err);
            return {
                status: 500,
                jsonBody: { success: false, error: 'An internal server error occurred' }
            };
        }
    }
});