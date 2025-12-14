const authenticate = (req, res, next) => {
  if (req.isAuthenticated()) {
    return next();
  }
  res.status(401).json({
    error: 'Unauthorized',
    message: 'Authentication required'
  });
};

module.exports = authenticate;