const { app } = require('@azure/functions');
const sql = require('mssql');
const crypto = require('crypto');

function generateCardId() {
    const epoch = Date.now().toString();
    const rand = Math.floor(Math.random() * 9000) + 1000;
    return `${epoch}-${rand}`;
}

function hashPin(pin) {
    return crypto.createHash('sha256').update(pin).digest('hex');
}

app.http('recover', {
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

        const pinHash = hashPin(pin);

        try {
            const pool = await sql.connect(process.env.SQL_CONNECTION_STRING);
            const tx = new sql.Transaction(pool);

            await tx.begin();

            let account;
            {
                const req = new sql.Request(tx);
                req.input('owner', sql.NVarChar(50), owner);
                req.input('pin_hash', sql.NVarChar(sql.MAX), pinHash);

                const r = await req.query(`
                    SELECT TOP 1
                        account_id,
                        tx_id,
                        owner,
                        balance,
                        card_id
                    FROM dbo.user_accounts
                    WHERE owner = @owner AND pin_hash = @pin_hash
                `);

                if (r.recordset.length === 0) {
                    await tx.rollback();
                    return {
                        jsonBody: { success: false, error: 'Owner name or PIN is incorrect' }
                    };
                }

                account = r.recordset[0];
            }

            let newCardId = null;
            let updated = null;

            for (let attempt = 0; attempt < 5; attempt++) {
                const candidate = generateCardId();

                const req = new sql.Request(tx);
                req.input('account_id', sql.Int, account.account_id);
                req.input('card_id', sql.NVarChar(50), candidate);

                const u = await req.query(`
                    UPDATE dbo.user_accounts
                    SET card_id = @card_id,
                        last_used = SYSUTCDATETIME()
                    OUTPUT 
                        inserted.account_id,
                        inserted.tx_id,
                        inserted.card_id,
                        inserted.owner,
                        inserted.balance,
                        inserted.pin_hash,
                        inserted.created_at,
                        inserted.last_used
                    WHERE account_id = @account_id
                      AND NOT EXISTS (
                          SELECT 1 FROM dbo.user_accounts WHERE card_id = @card_id
                      )
                `);

                if (u.recordset.length > 0) {
                    updated = u.recordset[0];
                    newCardId = updated.card_id;
                    break;
                }
            }

            if (!updated) {
                await tx.rollback();
                return {
                    status: 500,
                    jsonBody: { success: false, error: 'Failed to generate a unique card ID' }
                };
            }

            await tx.commit();

            return {
                jsonBody: {
                    success: true,
                    account_id: updated.account_id,
                    tx_id: updated.tx_id,
                    card_id: newCardId,
                    owner: updated.owner,
                    balance: updated.balance,
                    pin_hash: updated.pin_hash,
                    created_at: updated.created_at,
                    last_used: updated.last_used
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