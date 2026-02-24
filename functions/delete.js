const { app } = require('@azure/functions');
const sql = require('mssql');
const crypto = require('crypto');

function hashPin(pin) {
    return crypto.createHash('sha256').update(pin).digest('hex');
}

app.http('delete', {
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

        const { owner, pin, key } = body;

        if (key !== process.env.GATEWAY_SECRET) {
            return {
                status: 401,
                jsonBody: { success: false, error: 'Invalid authentication key' }
            };
        }

        if (!owner || typeof owner !== 'string' || owner.length > 50) {
            return {
                status: 400,
                jsonBody: { success: false, error: 'The owner field is required (max 50 chars)' }
            };
        }

        if (!pin || typeof pin !== 'string') {
            return {
                status: 400,
                jsonBody: { success: false, error: 'The pin field is required' }
            };
        }

        const DEFAULT_PIN_LENGTH = 6;
        if (pin.length !== DEFAULT_PIN_LENGTH || /\D/.test(pin)) {
            return {
                status: 400,
                jsonBody: { success: false, error: `PIN must be ${DEFAULT_PIN_LENGTH} digits` }
            };
        }

        const pin_hash = hashPin(pin);

        try {
            const pool = await sql.connect(process.env.SQL_CONNECTION_STRING);
            const tx = new sql.Transaction(pool);

            await tx.begin();

            const req = new sql.Request(tx);
            req.input('owner', sql.NVarChar(50), owner);
            req.input('pin_hash', sql.NVarChar(64), pin_hash);

            const deletedResult = await req.query(`
                DELETE FROM dbo.user_accounts
                OUTPUT 
                    deleted.account_id,
                    deleted.tx_id,
                    deleted.card_id,
                    deleted.owner,
                    deleted.balance,
                    deleted.pin_hash,
                    deleted.created_at,
                    deleted.last_used
                WHERE owner = @owner AND pin_hash = @pin_hash
            `);

            if (deletedResult.recordset.length === 0) {
                await tx.rollback();
                return {
                    jsonBody: { success: false, error: 'Account not found or invalid credentials' }
                };
            }

            await tx.commit();

            const deleted = deletedResult.recordset[0];

            return {
                jsonBody: {
                    success: true,
                    account_id: deleted.account_id,
                    tx_id: deleted.tx_id,
                    card_id: deleted.card_id,
                    owner: deleted.owner,
                    balance: deleted.balance,
                    pin_hash: deleted.pin_hash,
                    created_at: deleted.created_at,
                    last_used: deleted.last_used
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