const { app } = require('@azure/functions');
const sql = require('mssql');

app.http('auth', {
    methods: ['POST'],
    authLevel: 'anonymous',
    handler: async (request, context) => {
        let body;

        try {
            body = await request.json();
        } catch {
            return {
                status: 400,
                jsonBody: { success: false, error: 'The request body contains invalid JSON.' }
            };
        }

        const { card_id, key } = body;

        if (key !== process.env.GATEWAY_SECRET) {
            return {
                status: 401,
                jsonBody: { success: false, error: 'The provided authentication key is invalid.' }
            };
        }

        if (!card_id) {
            return {
                status: 400,
                jsonBody: { success: false, error: 'The card_id field is required.' }
            };
        }

        try {
            await sql.connect(process.env.SQL_CONNECTION_STRING);

            const result = await sql.query`
                UPDATE user_accounts
                SET last_used = SYSUTCDATETIME()
                OUTPUT 
                    inserted.account_id,
                    inserted.tx_id,
                    inserted.owner,
                    inserted.balance,
                    inserted.pin_hash,
                    inserted.created_at,
                    inserted.last_used
                WHERE card_id = ${card_id}
            `;

            if (result.recordset.length === 0) {
                return {
                    jsonBody: {
                        success: false,
                        error: 'The card ID does not exist in the system.'
                    }
                };
            }

            const account = result.recordset[0];

            return {
                jsonBody: {
                    success: true,
                    account_id: account.account_id,
                    tx_id: account.tx_id,
                    owner: account.owner,
                    balance: account.balance,
                    pin_hash: account.pin_hash,
                    created_at: account.created_at,
                    last_used: account.last_used
                }
            };

        } catch (err) {
            context.log(err);
            return {
                status: 500,
                jsonBody: {
                    success: false,
                    error: 'An internal server error occurred.'
                }
            };
        }
    }
});