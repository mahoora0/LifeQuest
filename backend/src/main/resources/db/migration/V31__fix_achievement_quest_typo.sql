UPDATE achievements
SET description = REPLACE(description, '퀴스트', '퀘스트')
WHERE description LIKE '%퀴스트%';

UPDATE titles
SET name = REPLACE(name, '퀴스트', '퀘스트'),
    description = REPLACE(description, '퀴스트', '퀘스트')
WHERE acquire_type = 'ACHIEVEMENT'
  AND (name LIKE '%퀴스트%' OR description LIKE '%퀴스트%');
