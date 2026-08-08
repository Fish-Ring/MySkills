/**
 * Data Migration Script: JSON to SQLite (v2.0 - No Chunk)
 * Run this once to migrate existing JSON data to SQLite
 */

const fs = require('fs');
const path = require('path');
const db = require('./db.js');

function migrate() {
    console.log('Starting migration from JSON to SQLite (v2.0)...');
    
    // 1. Migrate user_state.json
    const userStatePath = path.join(__dirname, '../../user_state.json');
    if (fs.existsSync(userStatePath)) {
        const userState = JSON.parse(fs.readFileSync(userStatePath, 'utf8'));
        
        db.updateProfile({
            target_exam: userState.profile.target_exam,
            vocabulary_level: userState.profile.vocabulary_level,
            grammar_basis: userState.profile.grammar_basis,
            total_words_count: userState.sys_meta.total_words_count
        });
        console.log('✓ User profile migrated');
        
        // Migrate review queue
        if (userState.review_queue && userState.review_queue.length > 0) {
            userState.review_queue.forEach(item => {
                db.addToReviewQueue(item.word, item.stage, item.next_review_time);
            });
            console.log(`✓ Review queue migrated (${userState.review_queue.length} items)`);
        }
        
        // Migrate history logs
        if (userState.history_logs && userState.history_logs.length > 0) {
            userState.history_logs.forEach(log => {
                db.addLog(log.date, log.type, log.count);
            });
            console.log(`✓ History logs migrated (${userState.history_logs.length} items)`);
        }
    }
    
    // 2. Migrate chunk files
    const vocabIndexPath = path.join(__dirname, '../../vocab_index.json');
    if (fs.existsSync(vocabIndexPath)) {
        const vocabIndex = JSON.parse(fs.readFileSync(vocabIndexPath, 'utf8'));
        
        for (const [word, chunkId] of Object.entries(vocabIndex)) {
            const chunkPath = path.join(__dirname, `../../chunk_${chunkId}.json`);
            if (fs.existsSync(chunkPath)) {
                const chunkData = JSON.parse(fs.readFileSync(chunkPath, 'utf8'));
                if (chunkData[word]) {
                    const wordData = chunkData[word];
                    db.addWord({
                        word: word,
                        pos: wordData.pos,
                        meaning: wordData.meaning,
                        frequency: wordData.frequency,
                        collocation: wordData.collocation,
                        example: wordData.example,
                        tips: wordData.tips,
                        tag: wordData.tag
                    });
                }
            }
        }
        console.log('✓ Words migrated from chunk files');
    }
    
    // Print stats
    const stats = db.getStats();
    console.log('\nMigration complete!');
    console.log('Stats:', stats);
}

migrate();
