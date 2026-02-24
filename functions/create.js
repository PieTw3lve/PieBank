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

app.http('create', {
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

        if (!owner || typeof owner !== 'string' || owner.length > 16) {
            return {
                status: 400,
                jsonBody: { success: false, error: 'The owner field is required (max 16 chars)' }
            };
        }

        if (!pin || typeof pin !== 'string' || !/^\d{6}$/.test(pin)) {
            return {
                status: 400,
                jsonBody: { success: false, error: 'PIN must be exactly 6 digits' }
            };
        }

        try {
            const pool = await sql.connect(process.env.SQL_CONNECTION_STRING);
            const tx = new sql.Transaction(pool);

            await tx.begin();

            {
                const req = new sql.Request(tx);
                req.input('owner', sql.NVarChar(50), owner);

                const r = await req.query(`
                    SELECT TOP 1 1 AS found
                    FROM dbo.user_accounts
                    WHERE owner = @owner
                `);

                if (r.recordset.length > 0) {
                    await tx.rollback();
                    return {
                        jsonBody: { success: false, error: 'That username is already taken' }
                    };
                }
            }

            const card_id = generateCardId();
            const pin_hash = hashPin(pin);

            const insertReq = new sql.Request(tx);
            insertReq.input('owner', sql.NVarChar(50), owner);
            insertReq.input('card_id', sql.NVarChar(50), card_id);
            insertReq.input('pin_hash', sql.NVarChar(sql.MAX), pin_hash);

            const inserted = await insertReq.query(`
                INSERT INTO dbo.user_accounts
                    (card_id, owner, balance, pin_hash, created_at, last_used)
                OUTPUT 
                    inserted.account_id,
                    inserted.tx_id,
                    inserted.card_id,
                    inserted.owner,
                    inserted.balance,
                    inserted.pin_hash,
                    inserted.created_at,
                    inserted.last_used
                VALUES
                    (@card_id, @owner, 0, @pin_hash, SYSUTCDATETIME(), SYSUTCDATETIME())
            `);

            await tx.commit();

            const account = inserted.recordset[0];

            return {
                jsonBody: {
                    success: true,
                    account_id: account.account_id,
                    tx_id: account.tx_id,
                    card_id: account.card_id,
                    owner: account.owner,
                    balance: account.balance,
                    pin_hash: account.pin_hash,
                    created_at: account.created_at,
                    last_used: account.last_used
                }
            };

        } catch (err) {
            context.log(err);

            if (String(err?.message || '').includes('sequence') ||
                String(err?.message || '').includes('MAXVALUE')) {
                return {
                    status: 500,
                    jsonBody: { success: false, error: 'No more transaction IDs available' }
                };
            }

            return {
                status: 500,
                jsonBody: { success: false, error: 'An internal server error occurred' }
            };
        }
    }
});