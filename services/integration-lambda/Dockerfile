FROM public.ecr.aws/lambda/python:3.12

# Copy function code
COPY index.py ${LAMBDA_TASK_ROOT}

# Set the CMD to the handler (index.py handler function)
CMD [ "index.handler" ]
