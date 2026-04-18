const Router = require('express');
const router = new Router();
const inventoryController = require('../controllers/inventory.controller');

router.get('/items', inventoryController.getItems);
router.get('/items/:id', inventoryController.getItemById);
router.post('/items', inventoryController.createItem);

module.exports = router;
