const { app } = require('@azure/functions');
const sql = require('mssql');

const BANK_ID = 'BANK';

app.http('transfer', {
    methods: ['POST'],
    authLevel: 'anonymous',
    handler: async (request, context) => {
        let body;

        try {
            body = await request.json();
        } catch {
            return { 
                status: 400,
                jsonBody: { 
                    success: false, 
                    error: 'Invalid JSON in request body' 
                }
            };
        }

        const { card_id, tx_id, amount, key } = body;

        if (key !== process.env.GATEWAY_SECRET) {
            return { 
                status: 401, 
                jsonBody: { 
                    success: false, 
                    error: 'Invalid authentication key' 
                } 
            };
        }

        const numericAmount = Number(amount);
        if (!Number.isInteger(numericAmount) || numericAmount <= 0) {
            return {
                status: 400,
                jsonBody: {
                    success: false,
                    error: 'Amount must be a positive whole number'
                }
            };
        }

        const raw = process.env.PROCESSING_RATE;

        if (raw === undefined || raw === null || raw === '') {
            return {
                status: 500,
                jsonBody: { success: false, error: 'PROCESSING_RATE is not configured' }
            };
        }

        const feeRate = Number(raw);

        if (!Number.isFinite(feeRate) || feeRate < 0) {
            return {
                status: 500,
                jsonBody: { success: false, error: 'PROCESSING_RATE is invalid (must be a number >= 0)' }
            };
        }

        let fee = 0;
        if (feeRate > 0) {
            fee = Math.max(1, Math.ceil(numericAmount * feeRate));
        }

        const totalCost = numericAmount + fee;

        try {
            await sql.connect(process.env.SQL_CONNECTION_STRING);
            const transaction = new sql.Transaction();
            await transaction.begin();

            {
                const req = new sql.Request(transaction);
                req.input('tx_id', sql.Int, tx_id);

                const recipientResult = await req.query(`
                    SELECT card_id 
                    FROM dbo.user_accounts 
                    WHERE tx_id = @tx_id
                `);

                if (recipientResult.recordset.length === 0) {
                    await transaction.rollback();
                    return { 
                        jsonBody: { 
                            success: false, 
                            error: 'Recipient account does not exist' 
                        } 
                    };
                }

                if (recipientResult.recordset[0].card_id === card_id) {
                    await transaction.rollback();
                    return { 
                        jsonBody: { 
                            success: false, 
                            error: 'Cannot transfer to the same account' 
                        } 
                    };
                }
            }

            let sender = null;
            {
                const req = new sql.Request(transaction);
                req.input('card_id', sql.NVarChar(50), card_id);
                req.input('total_cost', sql.Int, totalCost);

                const deductResult = await req.query(`
                    UPDATE dbo.user_accounts
                    SET balance = balance - @total_cost, last_used = SYSUTCDATETIME()
                    OUTPUT 
                        inserted.owner,
                        inserted.balance,
                        inserted.last_used
                    WHERE card_id = @card_id AND balance >= @total_cost
                `);

                if (deductResult.recordset.length === 0) {
                    await transaction.rollback();
                    return { 
                        jsonBody: { 
                            success: false, 
                            error: 'Insufficient funds or invalid card ID'
                        } 
                    };
                }

                sender = deductResult.recordset[0];
            }

            let receiver = null;
            {
                const req = new sql.Request(transaction);
                req.input('tx_id', sql.Int, tx_id);
                req.input('amount', sql.Int, numericAmount);

                const creditResult = await req.query(`
                    UPDATE dbo.user_accounts
                    SET balance = balance + @amount, last_used = SYSUTCDATETIME()
                    OUTPUT
                        inserted.owner,
                        inserted.balance,
                        inserted.last_used
                    WHERE tx_id = @tx_id
                `);

                if (creditResult.recordset.length === 0) {
                    await transaction.rollback();
                    return {
                        jsonBody: { success: false, error: 'Recipient account does not exist' }
                    };
                }

                receiver = creditResult.recordset[0];
            }

            {
                const req = new sql.Request(transaction);
                req.input('fee', sql.Int, fee);
                req.input('admin_id', sql.NVarChar(50), BANK_ID);

                await req.query(`
                    UPDATE dbo.admin_accounts
                    SET balance = balance + @fee, last_used = SYSUTCDATETIME()
                    WHERE admin_id = @admin_id
                `);
            }

            await transaction.commit();

            return {
                jsonBody: {
                    success: true,
                    sender: {
                        owner: sender.owner,
                        balance: sender.balance,
                        last_used: sender.last_used
                    },
                    receiver: {
                        owner: receiver.owner,
                        balance: receiver.balance,
                        last_used: receiver.last_used
                    },
                    fee
                }
            };

        } catch (err) {
            context.log(err);
            return { 
                status: 500, 
                jsonBody: { 
                    success: false, 
                    error: 'An internal server error occurred' 
                } 
            };
        }
    }
});